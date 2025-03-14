import std/[os, strutils]
import ./[action, common, config, jobs, target]
import pkg/cligen

let defaultConfigPath = block:
  let configDir = getEnv("XDG_CONFIG_HOME", getHomeDir() / ".config")
  configDir / "nmgr" / "config"

# TODO:
# let actionHelp = "Available actions: " & toSeq(actionRegistry.keys).join(", ")
# let targetHelp = "Available targets: " & toSeq(targetRegistry.keys).join(", ") &
#   ", a custom filter, specific job name, or string (for \"find\")"

proc main(
  # TODO: explicit positional args
  args: seq[string],
  # TODO: verbose default text
  config: string = defaultConfigPath,
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

  if version:
    # TODO:
    echo "not implemented"
    quit(0)
  if completion:
    # TODO:
    echo "not implemented"
    quit(0)

  if list_actions:
    for a in Action: echo a
    quit(0)
  if list_targets:
    for t in Target: echo t
    quit(0)
  if list_options:
    # TODO:
    echo "not implemented"
    quit(0)

  if args.len < 2:
    raise newException(HelpError, "Not enough arguments.\n\n${HELP}")

  let action = args[0]
  let target = args[1]
  let config = config.parse
  let jobs = target.filter(config)

  action.handle(jobs, NomadClient(), config)

when isMainModule:
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
