import std/[logging, os, strutils, tables]
import ./[action, common, config, jobs, target]
import pkg/cligen

# TODO:
# let actionHelp = "Available actions: " & toSeq(actionRegistry.keys).join(", ")
# let targetHelp = "Available targets: " & toSeq(targetRegistry.keys).join(", ") &
#   ", a custom filter, specific job name, or string (for \"find\")"

proc main(
  # TODO: explicit positional args
  args: seq[string],
  # TODO: verbose default text
  config: string = "",
  dry_run: bool = false,
  detach: bool = false,
  purge: bool = false,
  verbose: bool = false,
  completion: bool = false,
  version: bool = false,
  list_actions: bool = false,
  list_targets: bool = false,
  list_options: bool = false,
) =
  ## Nomad job manager CLI

  let logLevel =
    if verbose: lvlDebug
    else: lvlInfo

  let logger =
    newConsoleLogger(fmtStr = "$levelname: ", levelThreshold = logLevel)
  addHandler(logger)

  const targetRegistry = initTargetRegistry()
  const actionRegistry = initActionRegistry()

  let defaultConfigPath: string =
    getEnv("XDG_CONFIG_HOME", getHomeDir() / ".config") / "nmgr" / "config"

  if version:
    # TODO:
    info "not implemented"
    quit(0)
  if completion:
    # TODO:
    info "not implemented"
    quit(0)

  let parsedConfig =
    if config != "": config.parse
    else: defaultConfigPath.parse

  if list_actions:
    for a in actionRegistry.keys: echo a
    quit(0)
  if list_targets:
    for t in targetRegistry.keys: echo t
    for f in parsedConfig.filters.keys: echo f
    quit(0)
  if list_options:
    # TODO:
    info "not implemented"
    quit(0)

  if args.len < 2:
    raise newException(HelpError, "Missing arguments.\n\n${HELP}")

  let action = args[0]
  let target = args[1]
  let allJobs = findJobs(parsedConfig)
  let filteredJobs = target.filter(allJobs, targetRegistry, parsedConfig)

  action.handle(actionRegistry, filteredJobs, NomadClient(), parsedConfig)

when isMainModule:
  clCfg.helpSyntax = ""
  dispatch(main,
    cmdName = "nmgr",
    help = {
      "config": "path to config file",
      "dry_run": "simulate execution",
      "detach": "run jobs without waiting for completion",
      "purge": "completely remove jobs when stopping",
      "verbose": "show detailed output",
      "completion": "install Bash completion script and exit",
      "version": "show program version and exit",
      "list_actions": "CLIGEN-NOHELP",
      "list_targets": "CLIGEN-NOHELP",
      "list_options": "CLIGEN-NOHELP",
    },
    short = {
      "config": 'c',
      "dry_run": 'n',
      "detach": 'd',
      "purge": 'p',
      "verbose": 'v',
      "completion": '\0',
      "version": '\0',
      "list_actions": '\0',
      "list_targets": '\0',
      "list_options": '\0',
    },
  )
