import std/[dirs, files, paths, strformat, strscans, strutils]
import ./[config, errors, logging]

const specExts = [".hcl", ".nomad"]

type NomadJob* = object
  name*: string
  specPath*: Path
  isRunning*: bool
  isInfra*: bool

proc readSpec*(specPath: Path): string =
  try:
    readFile($specPath)
  except CatchableError as e:
    raise newException(JobError, fmt"Unable to read spec file {specPath}: {e.msg}")

func parseJobName(spec: string): string =
  for line in spec.splitLines():
    if line.strip().scanf("job$s\"$+\"", result):
      return

proc findConfigs*(jobDir: Path, configFilePatterns: seq[string]): seq[Path] =
  ## Finds configuration files in job directory
  for (kind, path) in walkDir(jobDir):
    if kind == pcFile:
      let fileName = $path.extractFilename
      for pattern in configFilePatterns:
        if fileName.contains(pattern):
          result.add(path)

proc matchesFilter*(job: NomadJob, filter: Filter, paths: seq[Path]): bool =
  ## Checks if any file in paths contains a line matching the pattern
  for path in paths:
    if not fileExists(path):
      continue
    for line in lines($path):
      if line.contains(filter.pattern):
        debug fmt"{job.name}: File '{path.extractFilename}' matches pattern '{filter.pattern}'"
        return true

proc getDefinedJobs*(config: Config): seq[NomadJob] =
  ## Finds Nomad jobs by walking subdirectories of base dir
  if not dirExists(config.baseDir):
    raise newException(JobError, fmt"Base directory not found: {config.baseDir}")

  for (kind, path) in walkDir(config.baseDir):
    if kind != pcDir or path.extractFilename in config.ignoreDirs:
      debug fmt"getDefinedJobs: Ignoring path: {path}"
      continue

    for (kind, path) in walkDir(path):
      if kind != pcFile or path.splitFile.ext notin specExts:
        continue

      let name = readSpec(path).parseJobName()
      if name == "":
        warn fmt"Could not extract job name from {path}"

      result.add(
        NomadJob(name: name, specPath: path, isInfra: name in config.infraJobs)
      )
