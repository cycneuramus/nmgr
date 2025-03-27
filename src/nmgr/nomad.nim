import std/[logging, osproc, paths, sequtils, strformat, strutils]
import ./[config, jobs]
import pkg/regex

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

  result = statusLines[0].toLower.contains("running")

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
  const pattern = re2("image\\s*=\\s*(\".*?\"|\\{[^}]*\\})", {regexDotAll})
  var matches: seq[string]

  for match in spec.findAll(pattern):
    let captureRange = match.group(0)
    if captureRange.a < 0:
      continue
    let matchStr = spec[captureRange.a .. captureRange.b].strip()

    # Skip reference to local HCL variables
    if matchStr.contains("local."):
      continue

    # If we caught a brace block, split out its content lines
    if matchStr.startsWith('{') and matchStr.endsWith('}'):
      let content = matchStr[1 .. matchStr.len - 2].strip()
      for line in content.splitLines:
        let trimmed = line.strip()
        if not trimmed.isEmptyOrWhitespace:
          matches.add(trimmed)
    else:
      # Otherwise, it's just a quoted string
      matches.add(matchStr)

  return matches.join("\n")

proc getLiveImage*(self; jobName: string): string =
  result = extractImages(self.inspectJob(jobName))

func getSpecImage*(self; spec: string): string =
  result = extractImages(spec)

proc getTasks*(self; jobName: string): seq[string] =
  const pattern = re2("task\\s+\"([^\"]+)")
  let spec = self.inspectJob(jobName)
  var matches: seq[string]

  for match in spec.findAll(pattern):
    matches.add(spec[match.group(0)])

  return matches
