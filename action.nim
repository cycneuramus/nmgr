import std/[logging, strformat, strutils]
import ./[common, config, jobs]

type
  Action* = enum
    Up = "up",
    Down = "down",
    Find = "find",
    List = "list",
    Image = "image",
    Logs = "logs",
    Reconcile = "reconcile"

template define(name: untyped, body: untyped) =
  ## Reduces boilerplate by centralizing the function signature of action handlers
  proc name(jobs {.inject.}: seq[NomadJob], nomad {.inject.}: NomadClient,
      cfg {.inject.}: Config): void =
    body

define(upHandler):
  echo "not implemented"

define(downHandler):
  echo "not implemented"

define(findHandler):
  echo "not implemented"

define(listHandler):
  for job in jobs:
    echo job.name

define(imageHandler):
  echo "not implemented"

define(logsHandler):
  echo "not implemented"

define(reconcileHandler):
  echo "not implemented"

proc handle*(action: string, jobs: seq[NomadJob], nomad: NomadClient,
    config: Config): void =
  let action =
    try:
      parseEnum[Action](action)
    except ValueError:
      # TODO: bubble up
      error fmt"Unknown action '{action}'"
      quit(1)

  let handle =
    case action
    of Action.Up: upHandler
    of Action.Down: downHandler
    of Action.Find: findHandler
    of Action.List: listHandler
    of Action.Image: imageHandler
    of Action.Logs: logsHandler
    of Action.Reconcile: reconcileHandler

  jobs.handle(nomad, config)
