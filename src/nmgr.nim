import std/[os, parsecfg, sequtils, streams, strformat, strutils, tables]
import ./nmgr/[action, args, completion, config, errors, jobs, logging, nomad, target]
import ./nmgr/nomad/[api, cli]
import pkg/argparse

proc main() =
  const
    version = staticRead("../nmgr.nimble").newStringStream.loadConfig.getSectionValue(
        "", "version"
      )
    defaultConfig = staticRead("../data/config")

  let defaultConfigPath =
    getEnv("XDG_CONFIG_HOME", getHomeDir() / ".config") / "nmgr" / "config"
  if not fileExists(defaultConfigPath):
    createDir(defaultConfigPath.parentDir)
    writeFile($defaultConfigPath, defaultConfig)
    echo fmt"Generated default config at {defaultConfigPath}"

  var parser = buildParser()
  let args =
    try:
      parseArgs()
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
    configPath = args.config_opt.get(otherwise = defaultConfigPath)
    parsedConfig =
      try:
        configPath.parse()
      except ConfigError as e:
        fatal e.msg
        quit(1)

  let action =
    try:
      parseEnum[Action](args.action)
    except ValueError:
      raise newException(ActionError, fmt"Unknown action: '{args.action}'")

  let nomad = NomadClient(
    config: parsedConfig,
    dryRun: args.dry_run,
    detach: args.detach,
    purge: args.purge,
    api: NomadApi(server: parsedConfig.server, http: newHttp()),
    cli: NomadCli(),
  )

  var jobs = getDefinedJobs(parsedConfig)
  if action notin offlineActions:
    let running = nomad.runningJobNames()
    for job in jobs.mitems:
      job.isRunning = job.name in running

  let targeted = args.targets.resolve(jobs, parsedConfig, adHoc = action == acFind)
  if targeted.len == 0:
    raise newException(TargetError, "No jobs targeted")
  if action in singleJobActions and targeted.len > 1:
    raise
      newException(ActionError, fmt "The '{action}' action only supports a single job")

  action.perform(targeted, nomad)

when isMainModule:
  main()
