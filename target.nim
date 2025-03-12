import std/algorithm
import ./[common, registry, jobs]

type
  TargetFilter* = proc(jobs: seq[NomadJob], config: Config): seq[NomadJob]

var targetRegistry* = newRegistry[TargetFilter]()

proc filter*(target: string, jobs: seq[NomadJob], config: Config): seq[NomadJob] =
  let filter = targetRegistry.get(target)
  jobs.filter(config)

proc infraFilter(jobs: seq[NomadJob], config: Config): seq[NomadJob] =
  ## Filters on infrastructure jobs, respecting their order in config
  for infraJobName in config.infraJobs:
    for job in jobs:
      if job.name == infraJobName:
        result.add(job)

registry.add(
  targetRegistry,
  "infra",
  infraFilter
)

proc servicesFilter(jobs: seq[NomadJob], config: Config): seq[NomadJob] =
  ## Filters on service (non-infrastructure) jobs
  for job in jobs:
    if job.name notin config.infraJobs:
      result.add(job)
  result = result.sortedByIt(it.name)

registry.add(
  targetRegistry,
  "services",
  servicesFilter
)

proc allFilter(jobs: seq[NomadJob], config: Config): seq[NomadJob] =
  # Filters on all (both infra and service) jobs, ordering infra jobs first
  result = infraFilter(jobs, config) & servicesFilter(jobs, config)

registry.add(
  targetRegistry,
  "all",
  allFilter
)

# TODO: for later use
# proc nameFilter(jobs: seq[NomadJob], config: Config, name: string): seq[NomadJob] =
#   # Fallback that filters on a single specific job by name
#   for job in jobs:
#     if job.name == name:
#       result.add(job)
