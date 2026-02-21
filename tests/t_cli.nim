import std/[unittest]
import ../src/nmgr/nomad/cli

suite "Nomad CLI":
  test "run with dryRun does not execute command":
    var
      cli = NomadCli()
      executed = false

    cli.caller = proc(
        cmd: seq[string], workingDir: string, captureOutput: bool
    ): string =
      executed = true
      return ""

    cli.run(@["nomad", "run", "job.hcl"], dryRun = true)

    check executed == false

  test "run with custom caller executes command":
    var
      cli = NomadCli()
      executed = false
      capturedCmd: seq[string] = @[]

    cli.caller = proc(
        cmd: seq[string], workingDir: string, captureOutput: bool
    ): string =
      executed = true
      capturedCmd = cmd
      return ""

    cli.run(@["nomad", "run", "job.hcl"], dryRun = false)

    check:
      executed == true
      capturedCmd == @["nomad", "run", "job.hcl"]

  test "run passes workingDir to caller":
    var
      cli = NomadCli()
      capturedWorkingDir = ""

    cli.caller = proc(
        cmd: seq[string], workingDir: string, captureOutput: bool
    ): string =
      capturedWorkingDir = workingDir
      return ""

    cli.run(@["nomad", "run", "job.hcl"], dryRun = false, workingDir = "/tmp/jobs")

    check capturedWorkingDir == "/tmp/jobs"

  test "run with empty workingDir passes empty string":
    var
      cli = NomadCli()
      capturedWorkingDir = ""

    cli.caller = proc(
        cmd: seq[string], workingDir: string, captureOutput: bool
    ): string =
      capturedWorkingDir = workingDir
      return ""

    cli.run(@["nomad", "run", "job.hcl"], dryRun = false)

    check capturedWorkingDir == ""
