import std/[os, paths, strformat]
import ./nmgr/[action, cli, config, errors, jobs, logging, nomad, target]
import pkg/argparse

proc main() =
  addHandler(newConsoleLogger(fmtStr = "$levelname: "))
  setLogFilter(lvlInfo)

  var argParser = buildParser()
  let args =
    try:
      argParser.parse()
    except ShortCircuit as e:
      handleShortCircuit(e)
      return

  if args.verbose:
    setLogFilter(lvlDebug)

  if not args.config_opt.isSome:
    ensureDefaultConfig()

  let
    config = parseConfig(args.config_opt.get($defaultConfigPath).Path)
    action =
      try:
        parseEnum[Action](args.action)
      except ValueError:
        raise newException(NmgrError, fmt"Unknown action: '{args.action}'")
    nomad = newNomadClient(config.server, args.dry_run, args.detach, args.purge)

  var jobs = definedJobs(config)
  if action notin offlineActions:
    if findExe("nomad").len == 0:
      raise newException(NmgrError, "'nomad' executable not found")

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
