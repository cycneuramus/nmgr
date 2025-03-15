import std/[algorithm, tables, sequtils, with]
import ./[config, jobs, registry]
# import pkg/regex

type
  TargetFilter = proc(jobs: seq[NomadJob], target: string, config: Config): seq[NomadJob]

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

proc initTargetRegistry*(): Registry[TargetFilter] =
  var registry = TargetFilter.initRegistry
  with registry:
    add("infra", infraFilter)
    add("services", servicesFilter)
    add("all", allFilter)
  return registry

proc filter*(target: string, jobs: seq[NomadJob], registry: Registry[TargetFilter],
    config: Config): seq[NomadJob] =
  let filter = block:
    if registry.hasKey(target):
      registry[target]
    elif config.filters.hasKey(target):
      configFilter
    else:
      nameFilter

  jobs.filter(target, config)
