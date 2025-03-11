## Represents and operates on Nomad jobs

import std/[
  paths,
  dirs,
  strformat,
  logging,
]

import ./common
import pkg/regex

const specExts = [".hcl", ".nomad"]

type
  NomadJob* = object
    name*: string
    specPath*: Path
    configPaths*: seq[Path]

proc getJobName(specPath: string): string =
  ## Extracts job name from Nomad spec file by finding `job "name"` pattern
  let pattern = re2("job\\s+\"([^\"]+)\"")
  var match = RegexMatch2()

  for line in lines(specPath):
    if find(line, pattern, match):
      return line[match.group(0)]

proc findConfigs(jobDir: Path, configExts: seq[string]): seq[Path] =
  ## Finds configuration files in job directory
  for (kind, path) in walkDir(jobDir):
    if kind != pcFile or path.splitFile.ext notin configExts:
      continue
    result.add(path)

# TODO: for later use
# proc readSpec(job: NomadJob): string =
#   try:
#     result = readFile(job.specPath.string)
#   except OSError as e:
#     warn fmt"Unable to read spec file {job.specPath}: {e.msg}"

# proc readConfigs(job: NomadJob): seq[string] =
#   for cfgFile in job.configPaths:
#     try:
#       result.add readFile(cfgFile.string)
#     except OSError as e:
#       warn fmt"Unable to read config file {cfgFile}: {e.msg}"

proc findJobs*(config: Config): seq[NomadJob] =
  # Finds Nomad jobs by walking subdirectories of base dir
  if not dirExists(config.baseDir):
    warn fmt"Base directory not found: {config.baseDir}"
    return

  for (kind, path) in walkDir(config.baseDir):
    if kind != pcDir or path.splitFile.dir in config.ignoreDirs:
      continue

    for (kind, path) in walkDir(path):
      if kind != pcFile or path.splitFile.ext notin specExts:
        continue

      let name = getJobName(path.string)
      if name == "":
        warn fmt"Could not extract job name from {path}"

      let configDir = parentDir(path)
      let configPaths = findConfigs(configDir, config.jobConfigExts)

      result.add(
        NomadJob(
          name: name,
          specPath: path,
          configPaths: configPaths
        )
      )
