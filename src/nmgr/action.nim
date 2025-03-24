import std/[logging, strformat, tables, with]
import ./[config, jobs, nomad, registry]

type ActionHandler = proc(jobs: seq[NomadJob], nomad: NomadClient, config: Config): void

using
  jobs: seq[NomadJob]
  nomad: NomadClient
  config: Config

proc upHandler(jobs, nomad, config): void =
  info "not implemented"

proc downHandler(jobs, nomad, config): void =
  info "not implemented"

proc findHandler(jobs, nomad, config): void =
  info "not implemented"

proc listHandler(jobs, nomad, config): void =
  for job in jobs:
    echo job.name

proc imageHandler(jobs, nomad, config): void =
  info "not implemented"

proc logsHandler(jobs, nomad, config): void =
  info "not implemented"

proc execHandler(jobs, nomad, config): void =
  info "not implemented"

proc reconcileHandler(jobs, nomad, config): void =
  info "not implemented"

func initActionRegistry*(): Registry[ActionHandler] =
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

proc handle*(
    action: string,
    registry: Registry[ActionHandler],
    jobs: seq[NomadJob],
    nomad: NomadClient,
    config: Config,
): void =
  let handle =
    if registry.hasKey(action):
      registry[action]
    else:
      # TODO: bubble up
      error fmt"Unknown action '{action}'"
      quit(1)

  jobs.handle(nomad, config)
