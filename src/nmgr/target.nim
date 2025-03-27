import std/[algorithm, sequtils, tables, with]
import ./[config, jobs, registry]

type TargetFilter = proc(jobs: seq[NomadJob], config: Config): seq[NomadJob]

using
  jobs: seq[NomadJob]
  config: Config
  target: string
  registry: Registry[TargetFilter]

func infraFilter(jobs, config): seq[NomadJob] =
  ## Filters on infrastructure jobs, ordering them as in config
  for infraJobName in config.infraJobs:
    result.add(jobs.filterIt(it.name == infraJobName))

func servicesFilter(jobs, config): seq[NomadJob] =
  ## Filters on service (non-infra) jobs, ordering them alphabetically
  result = jobs.filterIt(it.name notin config.infraJobs).sortedByIt(it.name)

func allFilter(jobs, config): seq[NomadJob] =
  ## Filters on all (both infra and service) jobs, ordering infra jobs first
  result = jobs.infraFilter(config) & jobs.servicesFilter(config)

func configFilter(target): TargetFilter =
  ## Filters on jobs matching config-defined patterns
  # configFilter is a special case needing a filter name param, whence the closure
  return proc(jobs, config): seq[NomadJob] =
    let filter = config.filters[target]
    for job in jobs:
      if filter.excludeInfra and job.name in config.infraJobs:
        continue

      var paths = @[job.specPath]
      if filter.extendedSearch:
        paths.add(job.configPaths)

      if job.matchesFilter(filter, paths, config):
        result.add(job)

    result = result.sortedByIt(it.name)

func nameFilter(target): TargetFilter =
  ## Filters on jobs matching the target job name
  # nameFilter is a special case needing a target param, whence the closure
  return proc(jobs, config): seq[NomadJob] =
    result = jobs.filterIt(it.name == target)

func initTargetRegistry*(): Registry[TargetFilter] =
  var registry = TargetFilter.initRegistry
  with registry:
    add("infra", infraFilter)
    add("services", servicesFilter)
    add("all", allFilter)
  return registry

proc filter*(target, jobs, registry, config): seq[NomadJob] =
  let filter =
    if registry.hasKey(target):
      registry[target]
    elif target in config.filters:
      configFilter(target)
    else:
      nameFilter(target)

  result = jobs.filter(config)
