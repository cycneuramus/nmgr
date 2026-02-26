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
    targetRegistry = initTargetRegistry()
    actionRegistry = initActionRegistry()

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
        fatal fmt"Error parsing config: {e.msg}"
        quit(1)

  let action =
    try:
      actionRegistry[args.action]
    except KeyError:
      fatal fmt"Unknown action: '{args.action}'"
      quit(1)
  debug fmt""" Action '{args.action}' found:
    nomadInterface: {action.nomadInterface},
    isSingleJob: {action.isSingleJob}""".dedent()

  let targets = args.targets

  let nomad = NomadClient(
    config: parsedConfig,
    dryRun: args.dry_run,
    detach: args.detach,
    purge: args.purge,
    api: NomadApi(server: parsedConfig.server, http: newHttp()),
    cli: NomadCli(),
  )

  var
    targetedJobs: seq[NomadJob]
    seenJobs: seq[string]

  let runningJobs =
    try:
      getRunningJobs(nomad)
    except CatchableError as e:
      fatal fmt"Error fetching running jobs: {e.msg}"
      quit(1)

  var definedJobs =
    try:
      getDefinedJobs(parsedConfig)
    except CatchableError as e:
      fatal fmt"Error getting defined jobs: {e.msg}"
      quit(1)

  for job in definedJobs.mitems:
    if runningJobs.anyIt(it.name == job.name):
      job.isRunning = true

  let allJobs = if action.nomadInterface == niApi: runningJobs else: definedJobs

  for target in targets:
    let filteredJobs =
      # NOTE: 'find' action is treated as an on-the-fly config filter for now
      if args.action == "find":
        configFilter(target)(allJobs, parsedConfig)
      else:
        try:
          target.filter(allJobs, targetRegistry, parsedConfig)
        except CatchableError as e:
          fatal fmt"Error filtering on target: {e.msg}"
          quit(1)

    # Deduplicate target args
    for job in filteredJobs:
      if job.name notin seenJobs:
        seenJobs.add(job.name)
        targetedJobs.add(job)

  debug fmt"Targeting jobs: {targetedJobs.mapIt(it.name)}"

  if action.isSingleJob and targetedJobs.len > 1:
    fatal fmt"The '{args.action}' action only supports a single job"
    quit(1)

  try:
    action.handle(targetedJobs, nomad, parsedConfig)
  except ActionError as e:
    fatal fmt"Error handling action: {e.msg}"
    quit(1)

when isMainModule:
  main()
