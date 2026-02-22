import std/[osproc, strformat, strutils]
import ../logging

type NomadCli* = object
  caller*: proc(cmd: seq[string], workingDir: string): string

using self: NomadCli

proc run*(self; cmd: seq[string], dryRun: bool, workingDir: string = ""): int =
  let cmdStr = cmd.join(" ")
  debug fmt"Executing command: {cmdStr}"

  if dryRun:
    info fmt"[DRY RUN] {cmdStr}"
    return 0

  if not self.caller.isNil:
    discard self.caller(cmd, workingDir)
    return 0

  let process = startProcess(
    command = cmd[0],
    args = cmd[1 ..^ 1],
    workingDir = workingDir,
    options = {poUsePath, poParentStreams},
  )

  result = process.waitForExit()
