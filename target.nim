import std/[algorithm, tables, sequtils, strutils]
import ./[config, jobs]
# import pkg/regex

type
  Target* = enum
    Infra = "infra",
    Services = "services",
    All = "all",

template define(name: untyped, body: untyped) =
  ## Centralizes the function signature of target filters
  # TODO: the target param is only used for non-built-in filters
  proc name(jobs {.inject.}: seq[NomadJob], target {.inject.}: string,
      config {.inject.}: Config): seq[NomadJob] =
    body

define(infraFilter):
  ## Filters on infrastructure jobs, ordering them as in the config
  for infraJobName in config.infraJobs:
    for job in jobs:
      if job.name == infraJobName:
        result.add(job)

define(servicesFilter):
  ## Filters on service (non-infra) jobs, ordering them alphabetically
  result = jobs
    .filterIt(it.name notin config.infraJobs)
    .sortedByIt(it.name)

define(allFilter):
  ## Filters on all (both infra and service) jobs, ordering infra jobs first
  result =
    infraFilter(jobs, target, config) & servicesFilter(jobs, target, config)

define(configFilter):
  ## Filters on jobs matching config-defined regex patterns
  discard
  # let filterOpts = config.filters.getOrDefault(name)
  # if "pattern" in filterOpts:
  #   let pattern = re2(filterOpts["pattern"])
  #   var match = RegexMatch2()
  # TODO: readSpec etc.

define(nameFilter):
  ## Filters on jobs matching the target job name
  result = jobs.filterIt(it.name == target)

proc filter*(target: string, config: Config): seq[NomadJob] =
  ## Returns filtered jobs according to user-input target
  let jobs = findJobs(config)
  # TODO: enums with special cases does not feel like brilliant design
  let filter = block:
    try:
      case parseEnum[Target](target)
      of Target.Infra: infraFilter
      of Target.Services: servicesFilter
      of Target.All: allFilter
    except ValueError:
      if config.filters.hasKey(target):
        configFilter
      else:
        nameFilter

  jobs.filter(target, config)
