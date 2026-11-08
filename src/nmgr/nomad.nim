import std/[algorithm, json, osproc, paths, strformat, strutils]
import ./[config, errors, jobs, logging]
import ./nomad/[api, hclparser, jsonparser]

type
  Runner* = proc(cmd: seq[string], workingDir: string): int
  NomadClient* = object
    config*: Config
    dryRun*, detach*, purge*: bool
    api*: NomadApi
    runCmd*: Runner

proc runProcess*(cmd: seq[string], workingDir = ""): int =
  let process = startProcess(
    cmd[0], workingDir, cmd[1 ..^ 1], options = {poUsePath, poParentStreams}
  )
  defer:
    process.close()
  process.waitForExit()

proc newNomadClient*(
    config: Config, dryRun = false, detach = false, purge = false
): NomadClient =
  NomadClient(
    config: config,
    dryRun: dryRun,
    detach: detach,
    purge: purge,
    api: NomadApi(server: config.server, send: httpTransport()),
    runCmd: runProcess,
  )

using self: NomadClient

proc run(self; cmd: seq[string], workingDir = ""): int =
  let cmdStr = cmd.join(" ")
  if self.dryRun:
    info fmt"[DRY RUN] {cmdStr}"
    return 0
  debug fmt"Executing: {cmdStr}"
  self.runCmd(cmd, workingDir)

func extractImages*(spec: string): seq[string] =
  let content = parseHcl(spec)
  result = content.getImages()

proc getSpecImage*(self; specPath: Path): seq[string] =
  let spec = readSpec(specPath)
  result = extractImages(spec).sorted()
  if result.len == 0:
    raise newException(NomadError, fmt"No spec images found in {$specPath}")

proc getJson(self; path: string): JsonNode =
  self.api.get(path).parseResponse()

proc getLiveImage*(self; jobName: string): seq[string] =
  result = self.getJson("/v1/job" & jobName).images.sorted()
  if result.len == 0:
    raise newException(NomadError, fmt"No live images found for {jobName}")

proc getTasks*(self; jobName: string): seq[string] =
  result = self.getJson("/v1/job/" & jobName).taskNames()
  if result.len == 0:
    raise newException(NomadError, fmt"No tasks found for {jobName}")

proc getAllocId*(self; jobName: string): string =
  result = self.getJson("/v1/job/" & jobName & "/allocations").runningAllocId()
  if result.len == 0:
    raise newException(NomadError, fmt"No allocation found for {jobName}")

proc runningJobNames*(self): seq[string] =
  result = self.getJson("/v1/jobs").runningJobNames()
  debug fmt"Running jobs from API: {result}"

proc runJob*(self; job: NomadJob): void =
  var cmd = @["nomad", "run"]
  if self.detach and job.name notin self.config.infraJobs:
    cmd.add("-detach")
  cmd.add($job.specPath)

  discard self.run(cmd, workingDir = $job.specPath.parentDir)
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
  discard self.run(cmd)

proc exec*(self; taskName: string, jobName: string, subCmd: seq[string]): int =
  let allocId = self.getAllocId(jobName)
  var cmd = @["nomad", "alloc", "exec", "-task", taskName, allocId]
  cmd.add(subCmd)
  result = self.run(cmd)
