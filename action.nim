import std/[logging, strformat, tables, with]
import ./[common, config, jobs, registry]

type
  ActionHandler = proc(jobs: seq[NomadJob], nomad: NomadClient, config: Config): void

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
  ## Centralizes the function signature of action handlers
  proc name(jobs {.inject.}: seq[NomadJob], nomad {.inject.}: NomadClient,
      config {.inject.}: Config): void =
    body

define(upHandler):
  echo "not implemented"

define(downHandler):
  echo "not implemented"

define(findHandler):
  echo "not implemented"

define(listHandler):
  for job in jobs: echo job.name

define(imageHandler):
  echo "not implemented"

define(logsHandler):
  echo "not implemented"

define(execHandler):
  echo "not implemented"

define(reconcileHandler):
  echo "not implemented"

proc initActionRegistry*(): Registry[ActionHandler] =
  var registry = ActionHandler.initRegistry
  with registry:
    add("up", upHandler)
    add("down", downHandler)
    add("find", findHandler)
    add("list", listHandler)
    add("image", imageHandler)
    add("logs", logsHandler)
    add("exec", execHandler)
    add("reconcile", reconcileHandler)
  return registry

proc handle*(action: string, registry: Registry[ActionHandler], jobs: seq[NomadJob],
    nomad: NomadClient, config: Config): void =
  let handle = block:
    if registry.hasKey(action):
      registry[action]
    else:
      # TODO: bubble up
      error fmt"Unknown action '{action}'"
      quit(1)

  jobs.handle(nomad, config)
