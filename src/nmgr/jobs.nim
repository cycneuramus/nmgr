## Represents and operates on Nomad jobs

import std/[dirs, logging, paths, strformat, strutils]
import ./config
import pkg/regex

const specExts = [".hcl", ".nomad"]

type NomadJob* = object
  name*: string
  specPath*: Path
  configPaths*: seq[Path]

proc getJobName(specPath: Path): string =
  ## Extracts job name from Nomad spec file by finding `job "name"` pattern
  let pattern = re2("job\\s+\"([^\"]+)\"")
  var match = RegexMatch2()
  for line in lines($specPath):
    if find(line, pattern, match):
      return line[match.group(0)]

proc findConfigs(jobDir: Path, configFilePatterns: seq[string]): seq[Path] =
  ## Finds configuration files in job directory
  for (kind, path) in walkDir(jobDir):
    if kind == pcFile:
      let fileName = $path.extractFilename
      for pattern in configFilePatterns:
        if fileName.contains(pattern):
          result.add(path)

proc readSpec*(job: NomadJob): string =
  try:
    result = readFile(job.specPath.string)
  except OSError as e:
    warn fmt"Unable to read spec file {job.specPath}: {e.msg}"

proc matchesFilter*(
    job: NomadJob, filter: Filter, paths: seq[Path], config: Config
): bool =
  ## Checks if any file in paths contains a line matching the pattern

  let matchesPattern: proc(line: string): bool =
    if filter.isRegex:
      let pattern = re2(filter.pattern)
      var match: RegexMatch2
      proc(line: string): bool =
        find(line, pattern, match)
    else:
      proc(line: string): bool =
        line.contains(filter.pattern)

  for path in paths:
    for line in lines($path):
      if line.matchesPattern:
        return true

  return false

proc findJobs*(config: Config): seq[NomadJob] =
  ## Finds Nomad jobs by walking subdirectories of base dir
  if not dirExists(config.baseDir):
    error fmt"Base directory not found: {config.baseDir.string}"
    return

  for (kind, path) in walkDir(config.baseDir):
    if kind != pcDir or path.splitFile.dir in config.ignoreDirs:
      continue

    for (kind, path) in walkDir(path):
      if kind != pcFile or path.splitFile.ext notin specExts:
        continue

      let name = getJobName(path)
      if name == "":
        warn fmt"Could not extract job name from {path.string}"

      let configDir = parentDir(path)
      let configPaths = findConfigs(configDir, config.jobConfigPatterns)

      result.add(NomadJob(name: name, specPath: path, configPaths: configPaths))
