import std/[cmdline, parseopt, strformat, tables]
import action

type
  Command* = object
    action*: Action
    target*: string
    flags*: Table[string, string]

proc parseCommandLine*(): Command =
  var
    p = initOptParser(commandLineParams())
    args: seq[string]
    allowedFlags: seq[string] = @[]

  # First pass: get action name
  for kind, key, val in p.getopt():
    if kind == cmdArgument:
      args.add(key)
    if args.len >= 1: break # Stop after first positional

  if args.len == 0:
    echo("Missing action")
    quit(1)

  result.action = findAction(args[0])
  if result.action.isNil:
    echo(fmt"Unknown action: {args[0]}")
    quit(1)

  # Second pass: parse remaining args
  var remainingArgs = commandLineParams()[1..^1]
  p = initOptParser(remainingArgs)

  result.target = ""
  result.flags = initTable[string, string]()

  for kind, key, val in p.getopt():
    case kind
    of cmdArgument:
      if result.target == "":
        result.target = key
      else:
        echo(fmt"Unexpected argument: {key}")
        quit(1)
    of cmdLongOption, cmdShortOption:
      if key in allowedFlags:
        result.flags[key] = val
      else:
        echo(fmt"Invalid flag for {result.action.name}")
    of cmdEnd: discard

when isMainModule:
  let cmd = parseCommandLine()
  cmd.action.handle(cmd.target)
