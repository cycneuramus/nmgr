import std/[dirs, paths, strformat, strscans, strutils]
import ./[config, errors, logging]

const specExts = [".hcl", ".nomad"]

type NomadJob* = object
  name*: string
  specPath*: Path
  isRunning*: bool
  isInfra*: bool

proc readSpec(specPath: Path): string =
  try:
    readFile($specPath)
  except CatchableError as e:
    raise newException(JobError, fmt"Unable to read spec file {specPath}: {e.msg}")

func parseJobName(spec: string): string =
  for line in spec.splitLines():
    if line.strip().scanf("job$s\"$+\"", result):
      return

proc definedJobs*(config: Config): seq[NomadJob] =
  ## Finds Nomad jobs by walking subdirectories of base dir
  if not dirExists(config.baseDir):
    raise newException(JobError, fmt"Base directory not found: {config.baseDir}")

  for (dirKind, dirPath) in walkDir(config.baseDir):
    if dirKind != pcDir:
      continue
    if dirPath.extractFilename in config.ignoreDirs:
      debug fmt"Ignoring directory: {dirPath}"
      continue

    for (fileKind, filePath) in walkDir(dirPath):
      if fileKind != pcFile or filePath.splitFile.ext notin specExts:
        continue

      let name = readSpec(filePath).parseJobName()
      if name == "":
        warn fmt"Could not extract job name from {filePath}"
        continue

      result.add(
        NomadJob(name: name, specPath: filePath, isInfra: name in config.infraJobs)
      )
