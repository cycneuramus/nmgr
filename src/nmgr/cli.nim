import tables

type CliOpt* = object
  key*: string
  short*: char
  help*: string

# Because it seems cligen can't introspect available options
const cliOpts*: array[10, CliOpt] = [
  CliOpt(key: "config", short: 'c', help: "path to config file"),
  CliOpt(key: "dry_run", short: 'n', help: "simulate execution"),
  CliOpt(key: "detach", short: 'd', help: "run jobs without waiting for completion"),
  CliOpt(key: "purge", short: 'p', help: "completely remove jobs when stopping"),
  CliOpt(key: "verbose", short: 'v', help: "show detailed output"),
  CliOpt(
    key: "completion", short: '\0', help: "install Bash completion script and exit"
  ),
  CliOpt(key: "version", short: '\0', help: "show program version and exit"),
  CliOpt(key: "list_actions", short: '\0', help: "CLIGEN-NOHELP"),
  CliOpt(key: "list_targets", short: '\0', help: "CLIGEN-NOHELP"),
  CliOpt(key: "list_options", short: '\0', help: "CLIGEN-NOHELP"),
]

func toHelpTable*(opts: openArray[CliOpt]): Table[string, string] =
  result = initTable[string, string]()
  for opt in opts:
    result[opt.key] = opt.help

func toShortTable*(opts: openArray[CliOpt]): Table[string, char] =
  result = initTable[string, char]()
  for opt in opts:
    if opt.short != '\0':
      result[opt.key] = opt.short
