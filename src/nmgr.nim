import std/[os, sequtils, streams, strformat]
import ./nmgr/[action, args, config, errors, jobs, logging, nomad, target]
import ./nmgr/nomad/[api, cli]
import pkg/argparse

proc main() =
  addHandler(newConsoleLogger(fmtStr = "$levelname: "))
  setLogFilter(lvlInfo)

  ensureDefaultConfig()

  var argParser = buildParser()
  let args =
    try:
      argParser.parse()
    except ShortCircuit as e:
      handleShortCircuit(e)
      return

  if args.verbose:
    setLogFilter(lvlDebug)
  if findExe("nomad").len == 0:
    raise newException(NmgrError, "'nomad' executable not found")

  let
    config = parseConfig(args.config_opt.get(otherwise = defaultConfigPath))
    action =
      try:
        parseEnum[Action](args.action)
      except ValueError:
        raise newException(NmgrError, fmt"Unknown action: '{args.action}'")
    nomad = NomadClient(
      config: config,
      dryRun: args.dry_run,
      detach: args.detach,
      purge: args.purge,
      api: NomadApi(server: config.server, http: newHttp()),
      cli: NomadCli(),
    )

  var jobs = getDefinedJobs(config)
  if action notin offlineActions:
    let running = nomad.runningJobNames()
    for job in jobs.mitems:
      job.isRunning = job.name in running

  let targeted = args.targets.resolve(jobs, config, adHoc = action == acFind)
  if targeted.len == 0:
    raise newException(TargetError, "No jobs targeted")
  if action in singleJobActions and targeted.len > 1:
    raise
      newException(NmgrError, fmt "The '{action}' action only supports a single job")

  action.perform(targeted, nomad)

when isMainModule:
  try:
    main()
  except CatchableError as e:
    fatal e.msg
    quit(1)
