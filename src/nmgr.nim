import std/[algorithm, logging, os, sequtils, strformat, strutils, tables]
import ./nmgr/[action, cli, config, jobs, nomad, target]
import pkg/cligen

const
  cligenHelp = toHelpTable(cliOpts)
  cligenShort = toShortTable(cliOpts)

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

  const targetRegistry = initTargetRegistry()
  const actionRegistry = initActionRegistry()

  let
    logLevel = if verbose: lvlDebug else: lvlInfo
    logger = newConsoleLogger(fmtStr = "$levelname: ", levelThreshold = logLevel)
  addHandler(logger)

  if findExe("nomad").isEmptyOrWhitespace:
    fatal fmt"`nomad` executable not found"
    quit(1)

  let
    defaultConfigPath: string =
      getEnv("XDG_CONFIG_HOME", getHomeDir() / ".config") / "nmgr" / "config"
    parsedConfig = if config != "": config.parse else: defaultConfigPath.parse

  if version:
    # TODO:
    info "not implemented"
    quit(0)
  if completion:
    # TODO:
    info "not implemented"
    quit(0)

  # Short-circuits for hidden bash completion flags
  if list_actions:
    for a in actionRegistry.keys:
      echo a
    quit(0)
  if list_targets:
    for t in targetRegistry.keys:
      echo t
    for f in parsedConfig.filters.keys:
      echo f
    quit(0)
  if list_options:
    let
      longOpts = cliOpts.mapIt("--" & $it.key.replace('_', '-')).sorted()
      shortOpts = cliOpts.filterIt(it.short != '\0').mapIt("-" & it.short).sorted()
    echo longOpts.join("\n")
    echo shortOpts.join("\n")
    quit(0)

  if args.len < 2:
    raise newException(HelpError, "Missing arguments.\n\n${HELP}")

  let
    action = args[0]
    target = args[1]
    allJobs = findJobs(parsedConfig)
    nomadClient =
      NomadClient(config: parsedConfig, dryRun: dry_run, detach: detach, purge: purge)
    filteredJobs =
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
  clCfg.helpSyntax = ""
  dispatch(main, cmdName = "nmgr", help = cligenHelp, short = cligenShort)
