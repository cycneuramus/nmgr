import
  std/[httpclient, json, logging, osproc, paths, sequtils, strformat, strutils, uri]
import ./[config, hclparser, http, jobs, jsonparser]

type
  NomadClient* = object
    config*: Config
    dryRun*: bool
    purge*: bool
    detach*: bool
    httpCaller*: HttpCaller
    cliCaller*: CliCaller

  HttpCaller* = proc(endpoint: string): string {.noSideEffect.}
  CliCaller* =
    proc(cmd: seq[string], workingDir: string = "", captureOutput: bool = false): string

using self: NomadClient

proc apiUrl*(self; path: string, query: seq[(string, string)] = @[]): string =
  var uri = parseUri(self.config.server)
  uri.path =
    if path.startsWith("/"):
      path
    else:
      "/" & path
  if query.len > 0:
    uri.query = encodeQuery(query)
  return $uri

#TODO: method param: get/delete
proc httpCall(self; path: string): string =
  let endpoint = self.apiUrl(path)
  if self.httpCaller.isNil:
    result = httpGet(endpoint).body
  else:
    result = self.httpCaller(endpoint)

proc cliCall*(
    self; cmd: seq[string], workingDir: string = "", captureOutput: bool = false
): string =
  let cmdStr = cmd.join(" ")
  debug fmt"Executing command: {cmdStr}"

  # For commands that modify state, honor dryRun
  if self.dryRun and not captureOutput:
    info fmt"[DRY RUN] {cmdStr}"
    return

  if not self.cliCaller.isNil:
    return self.cliCaller(cmd, workingDir, captureOutput)

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

  discard self.cliCall(cmd, workingDir = $job.specPath.parentDir)
  debug fmt"Started job: {job.name}"

# TODO: use httpCall
proc stopJob*(self; jobName: string): void =
  var queryParams: seq[(string, string)] = @[]
  if self.purge:
    queryParams.add(("purge", "true"))

  let endpoint = self.apiUrl("/v1/job/" & jobName, queryParams)
  if self.dryRun:
    info fmt"[DRY RUN] DELETE {endpoint}"
    return

  discard httpDelete(endpoint)
  info fmt"Stopped job: {jobName} (purge={self.purge})"

proc isRunning*(self; jobName: string): bool =
  let responseBody = self.httpCall("/v1/job/" & jobName)
  let response = responseBody.parseResponse()
  if not response.hasKey("Status"):
    return false
  let status = response["Status"].getStr.toLowerAscii
  result = status == "running"

proc tailLogs*(self; taskName: string, jobName: string): void =
  let cmd = @["nomad", "logs", "-f", "-task", taskName, "-job", jobName]
  discard self.cliCall(cmd)

proc exec*(self; taskName: string, jobName: string, subCmd: seq[string]): void =
  var cmd = @["nomad", "alloc", "exec", "-task", taskName, "-job", jobName]
  cmd.add(subCmd)
  echo self.cliCall(cmd)

func extractImages(spec: string): string =
  let content = parseHcl(spec)
  result = content.getImages().join("\n")

func getSpecImage*(self; spec: string): string =
  result = extractImages(spec)

proc getLiveImage*(self; jobName: string): string =
  let responseBody = self.httpCall("/v1/job/" & jobName)
  let response = responseBody.parseResponse()
  result = response.parseImages.join("\n")

proc getTasks*(self; jobName: string): seq[string] =
  let responseBody = self.httpCall("/v1/job/" & jobName)
  let response = responseBody.parseResponse()
  result = response.parseTasks

proc getRunningJobs*(self): seq[NomadJob] =
  let
    responseBody = self.httpCall("/v1/jobs")
    response = responseBody.parseResponse()
    jobs = parseJobs(response)

  result = jobs.mapIt(NomadJob(name: it))
  debug fmt"Running jobs from API: {result.mapIt(it.name)}"
