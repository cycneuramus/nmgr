import std/[algorithm, tables, sequtils]
import ./[config, jobs]
# import pkg/regex

type
  Target* = enum
    Infra = "infra",
    Services = "services",
    All = "all",

template funcF(name: untyped, body: untyped) =
  ## Centralizes the function signature of target filter funcs
  func name(jobs {.inject.}: seq[NomadJob], target {.inject.}: string,
      config {.inject.}: Config): seq[NomadJob] =
    body

template procF(name: untyped, body: untyped) =
  ## Centralizes the function signature of target filter procs
  proc name(jobs {.inject.}: seq[NomadJob], target {.inject.}: string,
      config {.inject.}: Config): seq[NomadJob] =
    body

funcF(infraFilter):
  ## Filters on infrastructure jobs, ordering them as in config
  for infraJobName in config.infraJobs:
    result.add(
      jobs.filterIt(it.name == infraJobName)
    )

funcF(servicesFilter):
  ## Filters on service (non-infra) jobs, ordering them alphabetically
  result = jobs
    .filterIt(it.name notin config.infraJobs)
    .sortedByIt(it.name)

funcF(allFilter):
  ## Filters on all (both infra and service) jobs, ordering infra jobs first
  result =
    jobs.infraFilter(target, config) & jobs.servicesFilter(target, config)

procF(configFilter):
  ## Filters on jobs matching config-defined regex patterns
  discard
  # let filterOpts = config.filters.getOrDefault(name)
  # if "pattern" in filterOpts:
  #   let pattern = re2(filterOpts["pattern"])
  #   var match = RegexMatch2()
  # TODO: readSpec etc.

funcF(nameFilter):
  ## Filters on jobs matching the target job name
  result = jobs.filterIt(it.name == target)

proc filter*(target: string, config: Config): seq[NomadJob] =
  ## Returns filtered jobs according to user-input target
  let jobs = findJobs(config)
  # TODO: enums with special cases does not feel like brilliant design
  let filter = block:
    case target
    of $Target.Infra: infraFilter
    of $Target.Services: servicesFilter
    of $Target.All: allFilter
    elif config.filters.hasKey(target):
      configFilter
    else:
      nameFilter

  jobs.filter(target, config)
