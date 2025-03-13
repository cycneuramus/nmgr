import std/[tables, parsecfg, sequtils, strutils, paths]

type
  Config* = object
    baseDir*: Path
    ignoreDirs*: seq[Path]
    infraJobs*: seq[string]
    jobConfigExts*: seq[string]
    filters*: Table[string, Table[string, string]]

proc parse*(configPath: string): Config =
  var cfg: Config
  let parser = loadConfig(configPath)

  cfg.baseDir = parser.getSectionValue("general", "base_dir",
      "").Path.expandTilde
  cfg.ignoreDirs = parser.getSectionValue("general", "ignore_dirs", "").split(
      " ").mapIt(it.Path)
  cfg.infraJobs = parser.getSectionValue("general", "infra_jobs", "").split(" ")
  cfg.jobConfigExts = parser.getSectionValue("general", "job_config_exts",
      "").split(" ")
  cfg.filters = initTable[string, Table[string, string]]()

  for section in parser.sections:
    if section.startsWith("filter."):
      let name = section.split(".")[1]
      var opts = initTable[string, string]()
      for key, val in parser[section].pairs:
        opts[key] = val
      cfg.filters[name] = opts

  return cfg
