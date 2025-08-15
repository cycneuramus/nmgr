import std/[httpclient, json, logging, options, paths, strformat, strutils, uri]
import ./[config, hclparser, jobs]

type NomadClient* = object
  config*: Config
  dryRun*: bool
  detach*: bool
  purge*: bool

using self: NomadClient

proc newHttp(self): HttpClient =
  var client = newHttpClient()
  client.headers.add("Content-Type", "application/json")
  client.headers.add("Accept", "application/json")
  return client

func apiUrl(self; path: string, query: seq[(string, string)] = @[]): string =
  var uri = parseUri(self.config.nomadUrl)
  uri.path = (if path.startsWith("/"): path else: "/" & path)
  if query.len > 0:
    uri.query = encodeQuery(query)
  $uri

proc postJson(
    self; path: string, body: JsonNode, query: seq[(string, string)] = @[]
): JsonNode =
  let url = self.apiUrl(path, query)
  let http = self.newHttp()
  debug fmt"POST {url}"

  if self.dryRun:
    info fmt"[DRY RUN] POST {url}"
    return %*{}

  let resp = http.request(url, httpMethod = HttpPost, body = $body)
  if resp.code.ord() < 200 or resp.code.ord() >= 300:
    error fmt"Nomad API POST failed ({resp.code}): {resp.body}"
    raise newException(CatchableError, "Nomad API error")

  if resp.headers.getOrDefault("Content-Type").toLowerAscii().startsWith(
    "application/json"
  ):
    return parseJson(resp.body)
  # Accept empty or non-JSON success responses as {} to avoid parse errors.
  return %*{}

proc getJson(self; path: string, query: seq[(string, string)] = @[]): JsonNode =
  let url = self.apiUrl(path, query)
  let http = self.newHttp()
  debug fmt"GET {url}"

  let resp = http.request(url, httpMethod = HttpGet)
  if resp.code.ord() < 200 or resp.code.ord() >= 300:
    error fmt"Nomad API GET failed ({resp.code}): {resp.body}"
    raise newException(CatchableError, "Nomad API error")

  if resp.headers.getOrDefault("Content-Type").toLowerAscii().startsWith(
    "application/json"
  ):
    return parseJson(resp.body)
  return %*{}

proc deleteJson(self; path: string, query: seq[(string, string)] = @[]): JsonNode =
  let url = self.apiUrl(path, query)
  let http = self.newHttp()
  debug fmt"DELETE {url}"

  if self.dryRun:
    info fmt"[DRY RUN] DELETE {url}"
    return %*{}

  let resp = http.request(url, httpMethod = HttpDelete)
  if resp.code.ord() < 200 or resp.code.ord() >= 300:
    error fmt"Nomad API DELETE failed ({resp.code}): {resp.body}"
    raise newException(CatchableError, "Nomad API error")

  if resp.body.len == 0:
    return %*{}
  if resp.headers.getOrDefault("Content-Type").toLowerAscii().startsWith(
    "application/json"
  ):
    return parseJson(resp.body)
  return %*{}

# TODO: This will not work with HCLs containing e.g. file() functions,
# since those are normally resolved client-side in Nomad's CLI
proc runJob*(self; job: NomadJob): void =
  ## Parse HCL -> JSON (server-side), then register.
  let hcl = readSpec($job.specPath)
  if hcl.len == 0:
    return

  let parseReq = %*{"JobHCL": hcl, "Canonicalize": true}
  let resp = self.postJson("/v1/jobs/parse", parseReq)
  # Be tolerant of response shape across Nomad versions:
  # - some return the Job object directly
  # - others return { "Job": { ... } }
  var jobJson: JsonNode
  if resp.hasKey("Job"):
    jobJson = resp["Job"]
  else:
    jobJson = resp
  if jobJson.kind != JObject:
    error "Nomad parse returned non-object; body did not look like JSON job spec"
    raise newException(CatchableError, "Nomad parse error")

  var payload = %*{"Job": jobJson}
  if self.detach and job.name notin self.config.infraJobs:
    ## no direct detach in API; submitting and returning immediately is equivalent
    discard # retained for semantics
  discard self.postJson("/v1/jobs", payload)
  debug fmt"Started/updated job: {job.name}"

proc stopJob*(self; jobName: string): void =
  var query: seq[(string, string)] = @[]
  if self.purge:
    query.add(("purge", "true"))
  discard self.deleteJson("/v1/job/" & jobName, query)
  debug fmt"Stopped job: {jobName} (purge={self.purge})"

proc isRunning*(self; jobName: string): bool =
  ## Read job and check Status == "running" (server's view).
  try:
    let json = self.getJson("/v1/job/" & jobName)
    var status = ""
    if json.hasKey("Status") and json["Status"].kind == JString:
      status = json["Status"].str
    result = status.toLowerAscii() == "running"
  except CatchableError:
    result = false

proc tailLogs*(self; taskName: string, jobName: string): void =
  ## TODO: implement via:
  ## 1) GET /v1/job/:job_id/allocations -> pick an active alloc
  ## 2) GET /v1/client/fs/logs/:alloc_id?task=...&type=stdout&follow=true
  ## This returns framed JSON with base64 "Data" chunks
  error "HTTP log streaming not implemented yet"

proc exec*(self; taskName: string, jobName: string, subCmd: seq[string]): void =
  ## TODO: implement WebSocket /v1/client/allocation/:alloc_id/exec
  error "HTTP exec not implemented yet"

proc readJob(self; jobName: string): JsonNode =
  ## Server-side job spec (JSON), includes TaskGroups/Tasks/Config
  self.getJson("/v1/job/" & jobName)

func extractImagesFromJson(job: JsonNode): seq[string] =
  ## Walk TaskGroups[].Tasks[].Config.image, skip local.* references.
  if not job.hasKey("TaskGroups"):
    return @[]

  for taskGrp in job["TaskGroups"].elems:
    if taskGrp.kind != JObject or not taskGrp.hasKey("Tasks"):
      continue

    for task in taskGrp["Tasks"].items:
      try:
        let driver =
          if task.hasKey("Driver") and task["Driver"].kind == JString:
            task["Driver"].str
          else:
            ""

        if not task.hasKey("Config"):
          continue

        let cfg = task["Config"]
        if (driver == "docker" or driver == "containerd" or driver == "podman") and
            cfg.hasKey("image"):
          let img = (if cfg["image"].kind == JString: cfg["image"].str
          else: "")
          if img.len > 0 and not img.contains("local."):
            result.add(img)
      except CatchableError:
        discard

proc getLiveImage*(self; jobName: string): string =
  try:
    let job = self.readJob(jobName)
    result = extractImagesFromJson(job).join("\n")
  except CatchableError:
    result = ""

func getSpecImage*(self; spec: string): string =
  let content = parseHcl(spec)
  result = content.getImages().join("\n")

proc getTasks*(self; jobName: string): seq[string] =
  ## From server-side JSON spec
  try:
    let job = self.readJob(jobName)
    if not job.hasKey("TaskGroups"):
      return

    for taskGrp in job["TaskGroups"].items:
      if taskGrp.kind != JObject or not taskGrp.hasKey("Tasks"):
        continue
      for task in taskGrp["Tasks"].items:
        if task.hasKey("Name"):
          result.add task["Name"].getStr("")
  except CatchableError:
    discard
