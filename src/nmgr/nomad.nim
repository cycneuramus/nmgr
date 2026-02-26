import std/[paths, sequtils, strformat]
import ./[config, errors, jobs, logging]
import ./nomad/[api, cli, hclparser, jsonparser]

type NomadClient* = object
  config*: Config
  dryRun*: bool
  purge*: bool
  detach*: bool
  api*: NomadApi
  cli*: NomadCli

using self: NomadClient

func extractImages*(spec: string): seq[string] =
  let content = parseHcl(spec)
  result = content.getImages()

proc getSpecImage*(self; specPath: Path): seq[string] =
  let spec = readSpec(specPath)
  result = extractImages(spec)
  if result.len == 0:
    raise newException(NomadError, fmt"No spec images found in {$specPath}")

proc getLiveImage*(self; jobName: string): seq[string] =
  let response = self.api.get("/v1/job/" & jobName).parseResponse()
  result = response.parseImages()
  if result.len == 0:
    raise newException(NomadError, fmt"No live images found for {jobName}")

proc getTasks*(self; jobName: string): seq[string] =
  let response = self.api.get("/v1/job/" & jobName).parseResponse()
  result = response.parseTasks()
  if result.len == 0:
    raise newException(NomadError, fmt"No tasks found for {jobName}")

proc getAllocId*(self; jobName: string): string =
  let response = self.api.get("/v1/job/" & jobName & "/allocations").parseResponse()
  result = response.parseAllocId()
  if result.len == 0:
    raise newException(NomadError, fmt"No allocation found for {jobName}")

proc getRunningJobs*(self): seq[NomadJob] =
  let
    response = self.api.get("/v1/jobs").parseResponse()
    jobs = response.parseJobs()
  for job in jobs:
    result.add(NomadJob(name: job, isRunning: true))
  debug fmt"Running jobs from API: {result.mapIt(it.name)}"

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

proc tailLogs*(self; taskName: string, jobName: string): void =
  let
    allocId = self.getAllocId(jobName)
    cmd = @["nomad", "logs", "-f", "-task", taskName, allocId]
  discard self.cli.run(cmd, self.dryRun)

proc exec*(self; taskName: string, jobName: string, subCmd: seq[string]): int =
  let allocId = self.getAllocId(jobName)
  var cmd = @["nomad", "alloc", "exec", "-task", taskName, allocId]
  cmd.add(subCmd)
  result = self.cli.run(cmd, self.dryRun)
