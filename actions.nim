import tables, strformat
import registry

# Placeholder types
type
  NomadClient* = object
  Config* = object
  NomadJob* = object

# Type alias for an ActionHandler procedure (function with side-effects)
type
  ActionHandler* = proc (nomad: NomadClient, cfg: Config, jobs: seq[
      NomadJob]): void

# Instantiates a global 'actions' registry to store different action handlers by name
var
  actions*: Registry[ActionHandler] = newRegistry[ActionHandler]()

# Retrieves the action handler corresponding to 'name' from the 'actions' registry
# and calls it with the provided arguments
proc handleAction*(name: string, nomad: NomadClient, cfg: Config, jobs: seq[
    NomadJob]): void =
  let actionHandler = get(actions, name)
  actionHandler(nomad, cfg, jobs)

# Placeholder action
proc upAction(nomad: NomadClient, cfg: Config, jobs: seq[NomadJob]): void =
  echo("not implemented")

# Registers the "up" action in our 'actions' registry with its corresponding handler
registry.add(actions, "up", upAction)
