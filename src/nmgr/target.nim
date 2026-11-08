import std/[algorithm, paths, sequtils, strformat, tables]
import ./[config, errors, jobs, logging]

# An enum here might be tempting to avoid writing the builtins again
# in select(), but would actually be worse since all other potential
# targets are strings and thus would need separate handling anyway.
const builtinTargets* = ["infra", "services", "all"]

using
  jobs: seq[NomadJob]
  config: Config

func infra(jobs, config): seq[NomadJob] =
  for name in config.infraJobs:
    result.add(jobs.filterIt(it.name == name))

func services(jobs, config): seq[NomadJob] =
  jobs.filterIt(it.isInfra == false).sortedByIt(it.name)

proc matching*(jobs; filter: Filter, config): seq[NomadJob] =
  for job in jobs:
    if filter.excludeInfra and job.isInfra:
      continue

    var paths = @[job.specPath]
    if filter.extendedSearch:
      let configs = findConfigs(job.specPath.parentDir, config.jobConfigPatterns)
      paths.add(configs)

    if job.matchesFilter(filter, paths):
      result.add(job)

  result = result.sortedByIt(it.name)

proc select(jobs; target: string, config): seq[NomadJob] =
  case target
  of "infra":
    jobs.infra(config)
  of "services":
    jobs.services(config)
  of "all":
    jobs.infra(config) & jobs.services(config)
  elif target in config.filters:
    debug fmt"Using config filter: {target}"
    jobs.matching(config.filters[target], config)
  else:
    jobs.filterIt(it.name == target)

proc resolve*(targets: seq[string], jobs; config; adHoc = false): seq[NomadJob] =
  for target in targets:
    let matched =
      if adHoc:
        jobs.matching(Filter(pattern: target), config)
      else:
        jobs.select(target, config)

    if matched.len == 0 and not adHoc:
      raise newException(TargetError, fmt"'{target}' not found")
    result.add(matched)

  result = result.deduplicate()
