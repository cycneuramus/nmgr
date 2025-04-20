import std/[logging, os, parsecfg, sequtils, streams, strformat, strutils, tables]
import ./nmgr/[action, config, jobs, nomad, target]
import pkg/argparse

proc main() =
  const version = staticRead("../nmgr.nimble").newStringStream.loadConfig
    .getSectionValue("", "version")

  const targetRegistry = initTargetRegistry()
  const actionRegistry = initActionRegistry()

  var parser = newParser("nmgr"):
    help("Nomad job manager")

    flag("-n", "--dry-run", help = "Simulate execution")
    flag("-d", "--detach", help = "Run jobs without waiting for completion")
    flag("-p", "--purge", help = "Completely remove jobs when stopping")
    flag("-v", "--verbose", help = "Show detailed output")
    flag("--version", help = "Show program version and exit", shortcircuit = true)
    flag("--completion", help = "Install Bash completion script", shortcircuit = true)
    flag(
      "--list-actions",
      help = "List all available actions", # TODO: auto-fill actions?
      hidden = true,
      shortcircuit = true,
    )
    flag(
      "--list-targets",
      help = "List all available targets", # TODO: auto-fill actions?
      hidden = true,
      shortcircuit = true,
    )
    flag(
      "--list-options",
      help = "List all available options",
      hidden = true,
      shortcircuit = true,
    )

    option("-c", "--config", help = "Path to config file")

    arg("action", help = "Action to perform")
    arg("target", help = "Target to operate on")

  let args =
    try:
      parser.parse()
    except ShortCircuit as e:
      if e.flag == "argparse_help":
        echo e.help
        quit(0)
      if e.flag == "version":
        echo version
        quit(0)
      if e.flag == "completion":
        echo "completion not implemented" # TODO:
        quit(0)
      if e.flag == "list_actions":
        for a in actionRegistry.keys:
          echo a
        quit(0)
      if e.flag == "list_targets":
        for t in targetRegistry.keys:
          echo t
        # FIXME: figure out how to access these
        # for f in parsedConfig.filters.keys:
        #   echo f
        quit(0)
      if e.flag == "list_options":
        echo "not implemented" # TODO
        quit(0)
      else:
        raise
    except UsageError as e:
      echo fmt"Error parsing arguments: {e.msg}"
      quit(1)

  let
    logLevel = if args.verbose: lvlDebug else: lvlInfo
    logger = newConsoleLogger(fmtStr = "$levelname: ", levelThreshold = logLevel)

  addHandler(logger)

  if findExe("nomad").isEmptyOrWhitespace:
    fatal fmt"'nomad' executable not found"
    quit(1)

  let
    defaultConfigPath =
      getEnv("XDG_CONFIG_HOME", getHomeDir() / ".config") / "nmgr" / "config"
    configPath = args.config_opt.get(otherwise = defaultConfigPath)
    parsedConfig = configPath.parse()

  let
    action = args.action
    target = args.target
    allJobs = findJobs(parsedConfig)
    nomadClient = NomadClient(
      config: parsedConfig, dryRun: args.dry_run, detach: args.detach, purge: args.purge
    )
    filteredJobs =
      # NOTE: 'find' action is treated as an on-the-fly config filter for now
      if action == "find":
        configFilter(target)(allJobs, parsedConfig)
      else:
        try:
          target.filter(allJobs, targetRegistry, parsedConfig)
        except CatchableError as e:
          fatal fmt"Error filtering on target: {e.msg}"
          quit(1)

  try:
    action.handle(actionRegistry, filteredJobs, nomadClient, parsedConfig)
  except CatchableError as e:
    fatal fmt"Error handling action: {e.msg}"
    quit(1)

when isMainModule:
  main()
