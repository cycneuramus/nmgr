import ./[common, config, jobs]

type
  ActionHandler = proc(jobs: seq[NomadJob], nomad: NomadClient, config: Config)
  Action* = enum
    Up = "up",
    # Down = "Down",
    # Find = "find",
    List = "list",
    # Image = "image",
    # Logs = "logs",
    # Reconcile = "reconcile"

proc upHandler(jobs: seq[NomadJob], nomad: NomadClient, cfg: Config): void =
  echo "not implemented"

proc listHandler(jobs: seq[NomadJob], nomad: NomadClient, cfg: Config): void =
  for job in jobs:
    echo job.name

proc handle*(action: Action, jobs: seq[NomadJob], nomad: NomadClient,
    config: Config): void =
  let handle: ActionHandler =
    case action
    of Action.Up: upHandler
    of Action.List: listHandler

  jobs.handle(nomad, config)
