import
  std/[httpclient, json, logging, osproc, paths, sequtils, strformat, strutils, uri]
import ./[config, hclparser, jobs]

type NomadClient* = object
  config*: Config
  dryRun*: bool
  purge*: bool
  detach*: bool

using self: NomadClient

proc newHttp(self): HttpClient =
  var client = newHttpClient()
  client.headers.add("Content-Type", "application/json")
  return client

proc apiUrl(self; path: string, query: seq[(string, string)] = @[]): string =
  var uri = parseUri(self.config.server)
  uri.path =
    if path.startsWith("/"):
      path
    else:
      "/" & path
  if query.len > 0:
    uri.query = encodeQuery(query)
  return $uri

# NOTE: disabled for now since job submission breaks on HCL2 functions such as file()
# proc postJson(
#     self; path: string, body: JsonNode, query: seq[(string, string)] = @[]
# ): JsonNode =
#   let url = self.apiUrl(path, query)
#   let httpClient = self.newHttp()
#   debug fmt"POST {url}"
#   debug fmt"Request body: {body}"
#
#   if self.dryRun:
#     info fmt"[DRY RUN] POST {url}"
#     return %*{}
#
#   let response = httpClient.request(url, httpMethod = HttpPost, body = $body)
#   debug fmt"Response status: {response.status}"
#
#   try:
#     result = parseJson(response.body)
#   except Exception as e:
#     error fmt"Failed to parse JSON response: {e.msg}"
#     result = %*{}

proc getJson(self; path: string, query: seq[(string, string)] = @[]): JsonNode =
  let url = self.apiUrl(path, query)
  let httpClient = self.newHttp()
  debug fmt"GET {url}"

  try:
    let response = httpClient.request(url, httpMethod = HttpGet)
    debug fmt"Response status: {response.status}"
    result = parseJson(response.body)
  except Exception as e:
    error fmt"Failed to get JSON response: {e.msg}"
    result = %*{}

proc deleteJson(self; path: string, query: seq[(string, string)] = @[]): JsonNode =
  let url = self.apiUrl(path, query)
  let httpClient = self.newHttp()
  debug fmt"DELETE {url}"

  if self.dryRun:
    info fmt"[DRY RUN] DELETE {url}"
    return %*{}

  let response = httpClient.request(url, httpMethod = HttpDelete)
  debug fmt"Response status: {response.status}"

  try:
    result = parseJson(response.body)
  except Exception as e:
    error fmt"Failed to parse JSON response: {e.msg}"
    result = %*{}

# TODO: remove once migration to HTTP API is complete
proc executeCmd(
    self; cmd: seq[string], workingDir: string = "", captureOutput: bool = false
): string =
  let cmdStr = cmd.join(" ")
  debug fmt"Executing command: {cmdStr}", if workingDir.len > 0: workingDir else: ""

  # For commands that modify state, honor dryRun
  if self.dryRun and not captureOutput:
    info fmt"[DRY RUN] {cmdStr}"
    return

  if captureOutput:
    let output = execProcess(
      command = cmd[0],
      args = cmd[1 ..^ 1],
      workingDir = workingDir,
      options = {poUsePath, poStdErrToStdOut},
    )
    return output.strip()

  let process = startProcess(
    command = cmd[0],
    args = cmd[1 ..^ 1],
    workingDir = workingDir,
    options = {poUsePath, poParentStreams},
  )
  discard process.waitForExit()

proc runJob*(self; job: NomadJob): void =
  var cmd = @["nomad", "run"]
  if self.detach and job.name notin self.config.infraJobs:
    cmd.add("-detach")
  cmd.add($job.specPath)

  discard self.executeCmd(cmd, workingDir = $job.specPath.parentDir)
  debug fmt"Started job: {job.name}"

# NOTE: disabled for now since job submission breaks on HCL2 functions such as file()
# proc runJob*(self; job: NomadJob): void =
#   let specContent = readFile($job.specPath)
#   if specContent.len == 0:
#     warn fmt"Empty spec file for job {job.name}"
#     return
#
#   let parseRequest = %*{"JobHCL": specContent, "Canonicalize": true}
#   let parsed = self.postJson("/v1/jobs/parse", parseRequest)
#   if not parsed.hasKey("ID"):
#     warn fmt"Parsed job missing ID; refusing to submit"
#     return
#
#   if self.dryRun:
#     info fmt"[DRY RUN] Would submit job: {job.name}"
#     return
#
#   let payload = %*{"Job": parsed}
#   discard self.postJson("/v1/jobs", payload)
#   info fmt"Started job: {job.name}"

proc stopJob*(self; jobName: string): void =
  var queryParams: seq[(string, string)] = @[]
  if self.purge:
    queryParams.add(("purge", "true"))

  discard self.deleteJson("/v1/job/" & jobName, queryParams)
  info fmt"Stopped job: {jobName} (purge={self.purge})"

proc isRunning*(self; jobName: string): bool =
  let jobJson = self.getJson("/v1/job/" & jobName)
  if not jobJson.hasKey("Status"):
    return false
  let status = jobJson["Status"].getStr.toLowerAscii
  result = status == "running"

# TODO: migrate to HTTP API
proc tailLogs*(self; taskName: string, jobName: string): void =
  let cmd = @["nomad", "logs", "-f", "-task", taskName, "-job", jobName]
  discard self.executeCmd(cmd)

# TODO: migrate to HTTP API
proc exec*(self; taskName: string, jobName: string, subCmd: seq[string]): void =
  var cmd = @["nomad", "alloc", "exec", "-task", taskName, "-job", jobName]
  cmd.add(subCmd)
  echo self.executeCmd(cmd)

func extractImagesFromJson(jobJson: JsonNode): seq[string] =
  if not jobJson.hasKey("TaskGroups"):
    return @[]
  for taskGroup in jobJson["TaskGroups"].items:
    if taskGroup.kind != JObject or not taskGroup.hasKey("Tasks"):
      continue
    for task in taskGroup["Tasks"].items:
      if task.kind != JObject:
        continue
      if not task.hasKey("Config"):
        continue

      let config = task["Config"]
      proc checkImage(node: JsonNode): seq[string] =
        if node.kind == JObject:
          if node.hasKey("image"):
            let image = node["image"].getStr("")
            if image.len > 0 and not image.contains("local."):
              result.add(image)
          for _, value in node:
            result = result & checkImage(value)
        elif node.kind == JArray:
          for item in node.items:
            result = result & checkImage(item)

      result = result & checkImage(config)

proc getLiveImage*(self; jobName: string): string =
  let jobJson = self.getJson("/v1/job/" & jobName)
  result = extractImagesFromJson(jobJson).join("\n")

func extractImages(spec: string): string =
  let content = parseHcl(spec)
  result = content.getImages().join("\n")

func getSpecImage*(self; spec: string): string =
  result = extractImages(spec)

proc getTasks*(self; jobName: string): seq[string] =
  let jobJson = self.getJson("/v1/job/" & jobName)
  if not jobJson.hasKey("TaskGroups"):
    return

  for taskGroup in jobJson["TaskGroups"].items:
    if taskGroup.kind != JObject or not taskGroup.hasKey("Tasks"):
      continue
    for task in taskGroup["Tasks"].items:
      if task.hasKey("Name"):
        result.add task["Name"].getStr("")

proc getRunningJobs*(self): seq[NomadJob] =
  let jobs = self.getJson("/v1/jobs")
  if jobs.kind != JArray:
    debug fmt"getRunningJobs: response is not an array"
    return
  for job in jobs:
    if job.kind != JObject:
      continue
    if not job.hasKey("Status"):
      continue
    let status = job["Status"].getStr.toLowerAscii
    if status == "running":
      if not job.hasKey("Name"):
        continue
      let name = job["Name"].getStr
      if name.len > 0:
        result.add(NomadJob(name: name))
  debug fmt"Running jobs from API: {result.mapIt(it.name)}"
