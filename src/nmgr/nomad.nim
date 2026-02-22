import std/[json, paths, strformat, strutils]
import ./[config, jobs, logging]
import ./nomad/[api, cli, hclparser, jsonparser]

type NomadClient* = object
  config*: Config
  dryRun*: bool
  purge*: bool
  detach*: bool
  api*: NomadApi
  cli*: NomadCli

using self: NomadClient

proc runJob*(self; job: NomadJob): void =
  var cmd = @["nomad", "run"]
  if self.detach and job.name notin self.config.infraJobs:
    cmd.add("-detach")
  cmd.add($job.specPath)

  discard self.cli.run(cmd, self.dryRun, workingDir = $job.specPath.parentDir)
  if self.dryRun:
    return

  info fmt"Started job: {job.name}"

proc stopJob*(self; jobName: string): void =
  var queryParams: seq[(string, string)] = @[]
  if self.purge:
    queryParams.add(("purge", "true"))

  if self.dryRun:
    info fmt"[DRY RUN] DELETE /v1/job/{jobName}?purge={self.purge}"
    return

  discard self.api.delete("/v1/job/" & jobName, queryParams)
  info fmt"Stopped job: {jobName} (purge={self.purge})"

proc isRunning*(self; jobName: string): bool =
  let responseBody = self.api.get("/v1/job/" & jobName)
  let response = responseBody.parseResponse()
  if not response.hasKey("Status"):
    return false
  let status = response["Status"].getStr.toLowerAscii
  result = status == "running"

proc tailLogs*(self; taskName: string, jobName: string): void =
  let cmd = @["nomad", "logs", "-f", "-task", taskName, "-job", jobName]
  discard self.cli.run(cmd, self.dryRun)

proc exec*(self; taskName: string, jobName: string, subCmd: seq[string]): int =
  var cmd = @["nomad", "alloc", "exec", "-task", taskName, "-job", jobName]
  cmd.add(subCmd)
  result = self.cli.run(cmd, self.dryRun)

func extractImages*(spec: string): seq[string] =
  let content = parseHcl(spec)
  result = content.getImages()

func getSpecImage*(self; spec: string): seq[string] =
  result = extractImages(spec)

proc getLiveImage*(self; jobName: string): seq[string] =
  let responseBody = self.api.get("/v1/job/" & jobName)
  let response = responseBody.parseResponse()
  result = response.parseImages

proc getTasks*(self; jobName: string): seq[string] =
  let responseBody = self.api.get("/v1/job/" & jobName)
  let response = responseBody.parseResponse()
  result = response.parseTasks

proc getRunningJobs*(self): seq[string] =
  let
    responseBody = self.api.get("/v1/jobs")
    response = responseBody.parseResponse()
    jobs = parseJobs(response)

  result = jobs
  debug fmt"Running jobs from API: {result}"
