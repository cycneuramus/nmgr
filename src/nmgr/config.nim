import std/[logging, tables, parsecfg, sequtils, strformat, strutils, paths, with]

type Config* = object
  baseDir*: Path
  ignoreDirs*: seq[Path]
  infraJobs*: seq[string]
  jobConfigExts*: seq[string]
  filters*: Table[string, Table[string, string]]

proc parse*(configPath: string): Config =
  var config: Config
  let parser =
    try:
      loadConfig(configPath)
    except IOError as e:
      fatal fmt"Error parsing config: {e.msg}"
      quit(1)

  with config:
    baseDir = parser.getSectionValue("general", "base_dir", "").Path.expandTilde
    ignoreDirs =
      parser.getSectionValue("general", "ignore_dirs", "").split(" ").mapIt(it.Path)
    infraJobs = parser.getSectionValue("general", "infra_jobs", "").split(" ")
    jobConfigExts = parser.getSectionValue("general", "job_config_exts", "").split(" ")
    filters = initTable[string, Table[string, string]]()

  for section in parser.sections:
    if section.startsWith("filter."):
      let name = section.split(".")[1]
      var opts = initTable[string, string]()
      for key, val in parser[section].pairs:
        opts[key] = val
      config.filters[name] = opts

  return config
