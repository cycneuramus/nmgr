import std/[logging, osproc, paths, sequtils, strformat, strutils]
import ./[config, hclparser, jobs]

type NomadClient* = object
  config*: Config
  dryRun*: bool
  detach*: bool
  purge*: bool

using self: NomadClient

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

proc stopJob*(self; jobName: string): void =
  var cmd = @["nomad", "stop"]
  if self.purge:
    cmd.add("-purge")
  cmd.add(jobName)

  discard self.executeCmd(cmd)
  debug fmt"Stopped job: {jobName}"

proc isRunning*(self; jobName: string): bool =
  let cmd = @["nomad", "job", "status", "-short", jobName]
  let output = self.executeCmd(cmd, captureOutput = true)
  let statusLines = output.splitlines.filterIt(it.contains("Status"))

  result =
    if statusLines.len == 0:
      false
    else:
      statusLines[0].toLower.contains("running")

proc tailLogs*(self; taskName: string, jobName: string): void =
  let cmd = @["nomad", "logs", "-f", "-task", taskName, "-job", jobName]
  discard self.executeCmd(cmd)

proc exec*(self; taskName: string, jobName: string, subCmd: seq[string]): void =
  var cmd = @["nomad", "alloc", "exec", "-task", taskName, "-job", jobName]
  cmd.add(subCmd)
  echo self.executeCmd(cmd)

proc inspectJob(self; jobName: string): string =
  let cmd = @["nomad", "job", "inspect", "-hcl", jobName]
  result = self.executeCmd(cmd, captureOutput = true)

func extractImages(spec: string): string =
  let content = parseHcl(spec)
  result = content.getImages().join("\n")

proc getLiveImage*(self; jobName: string): string =
  result = extractImages(self.inspectJob(jobName))

func getSpecImage*(self; spec: string): string =
  result = extractImages(spec)

proc getTasks*(self; jobName: string): seq[string] =
  let spec = self.inspectJob(jobName)
  let content = parseHcl(spec)
  result = content.getBlocksOfType("job")[0].getTasks()
