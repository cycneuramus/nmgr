import std/[algorithm, tables, sequtils, with]
import ./[config, jobs, registry]
# import pkg/regex

type
  TargetFilter = proc(jobs: seq[NomadJob], target: string, config: Config): seq[NomadJob]

using
  jobs: seq[NomadJob]
  target: string
  config: Config

func infraFilter(jobs, target, config): seq[NomadJob] =
  ## Filters on infrastructure jobs, ordering them as in config
  for infraJobName in config.infraJobs:
    result.add(
      jobs.filterIt(it.name == infraJobName)
    )

func servicesFilter(jobs, target, config): seq[NomadJob] =
  ## Filters on service (non-infra) jobs, ordering them alphabetically
  result = jobs
    .filterIt(it.name notin config.infraJobs)
    .sortedByIt(it.name)

func allFilter(jobs, target, config): seq[NomadJob] =
  ## Filters on all (both infra and service) jobs, ordering infra jobs first
  result =
    jobs.infraFilter(target, config) & jobs.servicesFilter(target, config)

proc configFilter(jobs, target, config): seq[NomadJob] =
  ## Filters on jobs matching config-defined regex patterns
  discard
  # let filterOpts = config.filters.getOrDefault(name)
  # if "pattern" in filterOpts:
  #   let pattern = re2(filterOpts["pattern"])
  #   var match = RegexMatch2()
  # TODO: readSpec etc.

func nameFilter(jobs, target, config): seq[NomadJob] =
  ## Filters on jobs matching the target job name
  result = jobs.filterIt(it.name == target)

func initTargetRegistry*(): Registry[TargetFilter] =
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
