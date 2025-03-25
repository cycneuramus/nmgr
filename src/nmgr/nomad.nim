import std/[logging, os, osproc, paths, sequtils, streams, strformat, strutils]
import ./[config, jobs]
import pkg/regex

type NomadClient* = object
  config*: Config
  dryRun*: bool
  detach*: bool
  purge*: bool

using self: NomadClient

proc execute(
    self;
    cmd: seq[string],
    cwd: string = "",
    captureOut: bool = false,
    streaming: bool = false,
): string =
  let cmdStr = cmd.join(" ")
  debug fmt"Executing command: {cmdStr}", if cwd.len > 0: cwd else: ""

  var output: string

  # For commands that modify state, honor dryRun
  if self.dryRun and not captureOut:
    info fmt"[DRY RUN] {cmdStr}"
    return output

  let process = startProcess(
    command = cmd[0],
    args = cmd[1 .. cmd.high],
    workingDir = cwd,
    options = {poUsePath, poStdErrToStdOut},
  )
  defer:
    process.close

  if streaming:
    var line: string
    while process.running:
      if process.outputStream.readLine(line):
        echo line
      else:
        # No line available right now; avoid tight CPU loop
        sleep(100)
  elif captureOut:
    output = process.outputStream.readAll

  discard process.waitForExit
  return output.strip

proc runJob*(self; job: NomadJob): void =
  var cmd = @["nomad", "run"]
  if self.detach and job.name notin self.config.infraJobs:
    cmd.add("-detach")
  cmd.add($job.specPath)

  discard self.execute(cmd, cwd = $job.specPath.parentDir)
  debug fmt"Started job: {job.name}"

proc stopJob*(self; jobName: string): void =
  var cmd = @["nomad", "stop"]
  if self.purge:
    cmd.add("-purge")
  cmd.add(jobName)

  discard self.execute(cmd)
  debug fmt"Stopped job: {jobName}"

proc isRunning*(self; jobName: string): bool =
  let cmd = @["nomad", "job", "status", "-short", jobName]
  let output = self.execute(cmd, captureOut = true)
  let statusLines = output.splitlines.filterIt(it.contains("Status"))

  result = statusLines[0].toLower.contains("running")

proc tailLogs*(self; taskName: string, jobName: string): void =
  let cmd = @["nomad", "logs", "-f", "-task", taskName, "-job", jobName]
  discard self.execute(cmd, streaming = true)

proc exec*(self; taskName: string, jobName: string, subCmd: seq[string]): void =
  var cmd = @["nomad", "alloc", "exec", "-task", taskName, "-job", jobName]
  cmd.add(subCmd)
  echo self.execute(cmd, captureOut = true)

proc inspectJob(self; jobName: string): string =
  let cmd = @["nomad", "job", "inspect", "-hcl", jobName]
  result = self.execute(cmd, captureOut = true)

func extractImages(spec: string): string =
  const pattern = re2("image\\s*=\\s*(\".*?\"|\\{[^}]*\\})", {regexDotAll})
  var matches: seq[string]

  for match in spec.findAll(pattern):
    let captureRange = match.group(0)
    if captureRange.a < 0:
      continue
    let matchStr = spec[captureRange.a .. captureRange.b].strip

    # Skip reference to local HCL variables
    if matchStr.contains("local."):
      continue

    # If we caught a brace block, split out its content lines
    if matchStr.startsWith('{') and matchStr.endsWith('}'):
      let content = matchStr[1 .. matchStr.len - 2].strip
      for line in content.splitLines:
        let trimmed = line.strip
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
