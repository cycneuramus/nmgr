import std/[algorithm, os, parsecfg, streams, strformat, strutils, tables]
import ./[action, completion, config, nomad, target]
import pkg/argparse

const
  version = staticRead("../../nmgr.nimble").newStringStream.loadConfig.getSectionValue(
      "", "version"
    )
  defaultConfig = staticRead("../../data/config")

let defaultConfigPath* =
  getEnv("XDG_CONFIG_HOME", getHomeDir() / ".config") / "nmgr" / "config"

proc ensureDefaultConfig*() =
  if not fileExists(defaultConfigPath):
    createDir(defaultConfigPath.parentDir)
    writeFile($defaultConfigPath, defaultConfig)
    echo fmt"Generated default config at {defaultConfigPath}"

# HACK: parse help text for --list-options
func listOpts*(help: string): seq[string] =
  for line in help.splitLines:
    let trimmed = line.strip()
    if trimmed.startsWith('-'):
      for chunk in trimmed.split({' ', ','}):
        if chunk.len > 1 and chunk[0] == '-':
          # Remove anything after '=' (e.g. "--config=CONFIG")
          let clean = chunk.split('=')[0]
          result.add(clean)
  result = result.sorted()

template buildParser*(): untyped =
  newParser("nmgr"):
    help("Nomad job manager")

    flag("-n", "--dry-run", help = "Simulate execution")
    flag("-d", "--detach", help = "Run jobs without waiting for completion")
    flag("-p", "--purge", help = "Completely remove jobs when stopping")
    flag("-v", "--verbose", help = "Show detailed output")
    flag("--version", help = "Show program version and exit", shortcircuit = true)
    flag("--completion", help = "Install Bash completion script", shortcircuit = true)
    flag(
      "--list-actions",
      help = "List all available actions",
      hidden = true,
      shortcircuit = true,
    )
    flag(
      "--list-targets",
      help = "List all available targets",
      hidden = true,
      shortcircuit = true,
    )
    flag(
      "--list-options",
      help = "List all available options",
      hidden = true,
      shortcircuit = true,
    )
    flag(
      "--list-running",
      help = "List running jobs from Nomad",
      hidden = true,
      shortcircuit = true,
    )

    option(
      "-c", "--config", help = "Path to config file (default: ~/.config/nmgr/config)"
    )

    arg("action", help = "Action to perform")
    arg("targets", help = "Targets to operate on", nargs = -1)

proc handleShortCircuit*(e: ref ShortCircuit) =
  case e.flag
  of "argparse_help":
    echo e.help
  of "version":
    echo version
  of "completion":
    genCompletion()
  of "list_actions":
    for a in Action:
      echo a
  of "list_targets":
    for t in builtinTargets:
      echo t
    for f in parseConfig(defaultConfigPath).filters.keys:
      echo f
  of "list_options":
    echo listOpts(e.help).join("\n")
  of "list_running":
    for job in newNomadClient(parseConfig(defaultConfigPath).server).runningJobNames():
      echo job
  else:
    raise e
  quit(0)
