import pkg/argparse

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
      "-c", "--config", help = fmt"Path to config file (default: ~/.config/nmgr/config)"
    )

    arg("action", help = "Action to perform")
    arg("targets", help = "Targets to operate on", nargs = -1)

template parseArgs*(): untyped =
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
      genCompletion()
      quit(0)
    if e.flag == "list_actions":
      for a in actionRegistry.keys:
        echo a
      quit(0)
    if e.flag == "list_targets":
      let config =
        try:
          parse(defaultConfigPath)
        except ConfigError as e:
          fatal e.msg
          quit(1)
      for t in targetRegistry.keys:
        echo t
      for f in config.filters.keys:
        echo f
      quit(0)
    if e.flag == "list_options":
      echo listOpts(parser.help).join("\n")
      quit(0)
    if e.flag == "list_running":
      let config =
        try:
          parse(defaultConfigPath)
        except ConfigError as e:
          fatal e.msg
          quit(1)
      let nomad = NomadClient(
        config: config, api: NomadApi(server: config.server, http: newHttp())
      )
      for job in nomad.getRunningJobs():
        echo job
      quit(0)
    else:
      raise
