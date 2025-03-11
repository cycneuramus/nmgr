import ./[common, registry, jobs]

type
  ActionHandler* = proc(nomad: NomadClient, cfg: Config, jobs: seq[
      NomadJob]): void

var actionRegistry* = newRegistry[ActionHandler]()

proc upHandler(nomad: NomadClient, cfg: Config, jobs: seq[NomadJob]): void =
  echo("not implemented")

registry.add(
  actionRegistry,
  "up",
  upHandler
)

proc listHandler(nomad: NomadClient, cfg: Config, jobs: seq[NomadJob]): void =
  for job in jobs:
    echo job.name

registry.add(
  actionRegistry,
  "list",
  listHandler
)
