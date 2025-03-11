import std/[
  os,
  tables,
  sequtils,
  strformat,
  strutils,
]

import ./[
  action,
  target
]

import pkg/cligen

let configPath = block:
  let configDir = getEnv("XDG_CONFIG_HOME", getHomeDir() / ".config")
  configDir / "nmgr" / "config.toml"

# TODO:
# let actionHelp = "Available actions: " & toSeq(actionRegistry.keys).join(", ")
# let targetHelp = "Available targets: " & toSeq(targetRegistry.keys).join(", ") &
#   ", a custom filter, specific job name, or string (for \"find\")"

proc main(
  # TODO: explicit positional args
  args: seq[string],
  # TODO: verbose default text
  config: string = configPath,
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
    echo toSeq(actionRegistry.keys).join("\n")
    quit(0)
  if list_targets:
    echo toSeq(targetRegistry.keys).join("\n")
    quit(0)
  if list_options:
    # TODO:
    echo "not implemented"
    quit(0)

  if args.len < 2:
    raise newException(HelpError, "Too few arguments.\n\n${HELP}")

  let action = args[0]
  if action != "" and not actionRegistry.hasKey(action):
    echo fmt"Unknown action '{action}'"
    quit(1)
  let target = args[1]
  if target != "" and not targetRegistry.hasKey(target):
    echo fmt"Unknown target '{target}'"
    quit(1)

  # TODO (remove):
  echo fmt"Executing action '{action}' on target '{target}' with config: {config}"
  echo fmt"Dry run: {dry_run}, Detach: {detach}, Purge: {purge}, Verbose: {verbose}"

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
    },
    short = {
      "config": 'c',
      "dry_run": 'n',
      "detach": 'd',
      "purge": 'p',
      "verbose": 'v',
      "completion": '\0',
      "version": '\0',
    },
    suppress = @["list_actions", "list_targets", "list_options"]
  )
