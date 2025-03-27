import std/[logging, parsecfg, paths, sequtils, strformat, strutils, tables, with]

type
  Filter* = object
    name*: string
    pattern*: string
    extendedSearch*: bool
    excludeInfra*: bool
    isRegex*: bool

  Config* = object
    baseDir*: Path
    ignoreDirs*: seq[Path]
    infraJobs*: seq[string]
    jobConfigPatterns*: seq[string]
    filters*: Table[string, Filter]

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
    jobConfigPatterns =
      parser.getSectionValue("general", "job_config_patterns", "").split(" ")
    filters = initTable[string, Filter]()

  for section in parser.sections:
    if section.startsWith("filter."):
      let name = section.split(".")[1]
      let filter = parser[section]
      config.filters[name] = Filter(
        name: name,
        pattern: filter.getOrDefault("pattern", ""),
        extendedSearch: filter.getOrDefault("extended_search", "false").parseBool,
        excludeInfra: filter.getOrDefault("exclude_infra", "false").parseBool,
        isRegex: filter.getOrDefault("is_regex", "false").parseBool,
      )

  return config
