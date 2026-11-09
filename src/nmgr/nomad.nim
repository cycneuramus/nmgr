import std/[algorithm, json, osproc, paths, streams, strformat, strutils]
import ./[errors, jobs, logging]
import ./nomad/[api, jsonparser]

type
  Runner* = proc(cmd: seq[string], workingDir: Path): int
  Capturer* = proc(cmd: seq[string], workingDir: Path): string
  NomadClient* = object
    dryRun*, detach*, purge*: bool
    api*: NomadApi
    runCmd*: Runner
    captureCmd*: Capturer

proc runProcess*(cmd: seq[string], workingDir = Path("")): int =
  let process = startProcess(
    cmd[0], $workingDir, cmd[1 ..^ 1], options = {poUsePath, poParentStreams}
  )
  defer:
    process.close()
  process.waitForExit()

proc captureProcess*(cmd: seq[string], workingDir = Path("")): string =
  let process = startProcess(cmd[0], $workingDir, cmd[1 ..^ 1], options = {poUsePath})
  defer:
    process.close()
  result = process.outputStream.readAll()
  let errOut = process.errorStream.readAll().strip()
  if process.waitForExit() != 0:
    let cmdStr = cmd.join(" ")
    raise newException(NomadError, fmt"{cmdStr} failed: {errOut}")

proc newNomadClient*(
    server: string, dryRun = false, detach = false, purge = false
): NomadClient =
  NomadClient(
    dryRun: dryRun,
    detach: detach,
    purge: purge,
    api: NomadApi(server: server, send: httpTransport()),
    runCmd: runProcess,
    captureCmd: captureProcess,
  )

using self: NomadClient

proc run(self; cmd: seq[string], workingDir = Path("")): int =
  let cmdStr = cmd.join(" ")
  if self.dryRun:
    info fmt"[DRY RUN] {cmdStr}"
    return 0
  debug fmt"Executing: {cmdStr}"
  if self.runCmd(cmd, workingDir) != 0:
    raise newException(NomadError, fmt"Execution failed: {cmdStr}")

proc getJson(self; path: string): JsonNode =
  self.api.get(path).parseNomadJson()

proc getLiveImages*(self; jobName: string): seq[string] =
  result = self.getJson("/v1/job/" & jobName).images.sorted()

proc getSpecImages*(self; job: NomadJob): seq[string] =
  let output = self.captureCmd(
    @["nomad", "job", "run", "-output", $job.specPath], job.specPath.parentDir
  )
  output.parseNomadJson(){"Job"}.images.sorted()

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

proc runJob*(self; job: NomadJob) =
  var cmd = @["nomad", "run"]
  if self.detach and not job.isInfra:
    cmd.add("-detach")
  cmd.add($job.specPath)

  discard self.run(cmd, workingDir = job.specPath.parentDir)
  if self.dryRun:
    return

  info fmt"Started job: {job.name}"

proc stopJob*(self; jobName: string) =
  var queryParams: seq[(string, string)] = @[]
  if self.purge:
    queryParams.add(("purge", "true"))

  if self.dryRun:
    info fmt"[DRY RUN] DELETE /v1/job/{jobName}?purge={self.purge}"
    return

  discard self.api.delete("/v1/job/" & jobName, queryParams)
  info fmt"Stopped job: {jobName} (purge={self.purge})"

proc tailLogs*(self; taskName: string, jobName: string) =
  let
    allocId = self.getAllocId(jobName)
    cmd = @["nomad", "logs", "-f", "-task", taskName, allocId]
  discard self.run(cmd)

proc exec*(self; taskName: string, jobName: string, subCmd: seq[string]): int =
  let allocId = self.getAllocId(jobName)
  var cmd = @["nomad", "alloc", "exec", "-task", taskName, allocId]
  cmd.add(subCmd)
  result = self.run(cmd)
