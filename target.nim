import std/algorithm
import ./[config, jobs]

type
  Target* = enum
    Infra = "infra",
    Services = "services",
    All = "all",

template define(name: untyped, body: untyped) =
  ## Reduces boilerplate by centralizing the function signature of target filters
  proc name(jobs {.inject.}: seq[NomadJob], config {.inject.}: Config): seq[NomadJob] =
    body

define(infraFilter):
  ## Filters on infrastructure jobs, respecting their order in config
  for infraJobName in config.infraJobs:
    for job in jobs:
      if job.name == infraJobName:
        result.add(job)

define(servicesFilter):
  ## Filters on service (non-infrastructure) jobs
  for job in jobs:
    if job.name notin config.infraJobs:
      result.add(job)
  result = result.sortedByIt(it.name)

define(allFilter):
  ## Filters on all (both infra and service) jobs, ordering infra jobs first
  result = infraFilter(jobs, config) & servicesFilter(jobs, config)

# TODO: for later use
# proc nameFilter(jobs: seq[NomadJob], config: Config, name: string): seq[NomadJob] =
#   # Fallback that filters on a single specific job by name
#   for job in jobs:
#     if job.name == name:
#       result.add(job)

proc filter*(target: Target, jobs: seq[NomadJob], config: Config): seq[NomadJob] =
  let filter =
    case target
    of Target.Infra: infraFilter
    of Target.Services: servicesFilter
    of Target.All: allFilter
    # else: nameFilter

  jobs.filter(config)
