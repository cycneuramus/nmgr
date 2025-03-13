import std/[
  os,
  tables,
  strformat,
  strutils,
  paths
]

import ./[
  action,
  common,
  jobs,
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
    raise newException(HelpError, "Too few arguments.\n\n${HELP}")

  let action =
    try:
      parseEnum[Action](args[0])
    except ValueError:
      echo fmt"Unknown action '{args[0]}'"
      quit(1)

  let target =
    try:
      parseEnum[Target](args[1])
    except ValueError:
      echo fmt"Unknown target '{args[1]}'"
      quit(1)

  # TODO (remove):
  echo fmt"Executing action '{action}' on target '{target}' with config: {config}"
  echo fmt"Dry run: {dry_run}, Detach: {detach}, Purge: {purge}, Verbose: {verbose}"

  # Hard-code for testing TODO: remove
  let config = Config(
    baseDir: Path(expandTilde("~/cld")),
    ignoreDirs: @[Path(".git"), Path(".github"), Path("_archive")],
    infraJobs: @["garage", "keydb", "haproxy", "caddy", "patroni"],
    jobConfigExts: @[".env", ".toml", ".yml", ".yaml", ".sh", ".cfg", ".js", ".tpl"]
  )

  let allJobs = findJobs(config)
  let filteredJobs = target.filter(allJobs, config)
  action.handle(filteredJobs, NomadClient(), config)

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
