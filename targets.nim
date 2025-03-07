import tables, strformat
import registry

# Placeholder types
type
  NomadClient* = object
  Config* = object
  NomadJob* = object

# Type alias for a TargetHandler procedure (function with side-effects)
type
  TargetHandler* = proc (jobs: seq[NomadJob], cfg: Config): seq[NomadJob]

# Instantiates a global 'targets' registry to store different target handlers by name
var
  targets*: Registry[TargetHandler] = newRegistry[TargetHandler]()

# Retrieves the target corresponding to 'name' from the 'targets' registry
# and returns the corresponding handler
proc filterTarget*(name: string, jobs: seq[NomadJob], cfg: Config): seq[NomadJob] =
  # 1) Built-in target?
  if name in targets:
    return targets[name](jobs, cfg)

  # 2) Config-defined target?

  # 3) Fallback: treat target as a job name

# Placeholder target
proc infraTarget(jobs: seq[NomadJob], cfg: Config): seq[NomadJob] =
  echo("not implemented")
  return @[] # placeholder

# Registers the "infra" target in our 'targets' registry with its corresponding filter
registry.add(targets, "up", infraTarget)
