import common, registry

type
  TargetFilter* = proc(jobs: seq[NomadJob], cfg: Config): seq[NomadJob]

var targetRegistry* = newRegistry[TargetFilter]()

proc allFilter(jobs: seq[NomadJob], cfg: Config): seq[NomadJob] =
  echo("not implemented")
  return @[]

registry.add(
  targetRegistry,
  "all",
  allFilter
)
