import ./[common, registry]

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
