import std/[paths, tables]

# Placeholders
type
  Config* = object
    baseDir*: Path
    ignoreDirs*: seq[Path]
    infraJobs*: seq[string]
    jobConfigExts*: seq[string]
    filters*: Table[string, Table[string, string]]

  NomadClient* = object
