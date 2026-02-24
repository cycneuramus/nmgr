import std/[algorithm, sequtils, strformat, tables, with]
import ./[config, errors, jobs, logging, registry]

type TargetFilter* = proc(jobs: seq[NomadJob], config: Config): seq[NomadJob]

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

func configFilter*(target): TargetFilter =
  ## Filters on jobs matching config-defined patterns
  # NOTE: configFilter is a special case needing a filter name param, whence the closure
  return proc(jobs, config): seq[NomadJob] =
    let filter =
      try:
        config.filters[target]
      except KeyError:
        # HACK: On-the-fly filter fallback for 'find' action
        Filter(pattern: target)

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
  # NOTE: nameFilter is a special case needing a target param, whence the closure
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
  debug fmt"Filtering jobs on target: {target}"
  let targetFilter =
    if registry.hasKey(target):
      debug fmt"Using registry filter: {target}"
      registry[target]
    elif target in config.filters:
      debug fmt"Using config filter: {target}"
      configFilter(target)
    else:
      debug fmt"Using name filter: {target}"
      nameFilter(target)

  result = targetFilter(jobs, config)
  debug fmt"Target filter result: {result.len} jobs matched"

  if result.len == 0:
    raise newException(TargetError, fmt"'{target}' not found")
