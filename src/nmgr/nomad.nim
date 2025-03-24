import std/[logging, paths, strformat]
import ./[config, jobs]

type NomadClient* = object
  config: Config
  dryRun: bool
  detach: bool
  purge: bool

using
  self: NomadClient

proc execute(self; cmd: string, cwd: Path): void =
  discard

proc runJob*(self; job: NomadJob): void =
  var cmd = "nomad run"
  if self.detach and job.name notin self.config.infraJobs:
    cmd.add(" -detach")
  cmd.add( $job.specPath)

  self.execute(cmd, cwd = job.specPath.parentDir)
  debug fmt"Started job: {job.name}"

proc stopJob*(self; jobName: string): void =
  var cmd = "nomad stop"
  if self.purge:
    cmd.add(" -purge")
  cmd.add( jobName)

  self.execute(cmd, "".Path) # TODO: cwd in execute should be optional
  debug fmt"Stopped job: {jobName}"

proc isRunning(self; jobName: string): void =
  discard

proc tailLogs(self; taskName: string, jobName: string): void =
  discard

proc exec(self; taskName: string, jobName: string, cmd: seq[string]): void =
  discard

proc inspectJob(self; jobName: string): string =
  discard

proc getLiveImage(self; jobName: string): string =
  discard

proc getSpecImage(self; jobName: string): string =
  discard

proc extractTasks(self; jobName: string): seq[string] =
  discard

proc extractImages(spec: string): string =
  discard
