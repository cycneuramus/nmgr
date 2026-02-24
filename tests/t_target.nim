import std/[paths, tables, unittest]
import ../src/nmgr/[config, errors, jobs, target]

func makeConfig(infraJobs: seq[string] = @[]): Config =
  Config(
    baseDir: "/tmp".Path,
    infraJobs: infraJobs,
    filters: initTable[string, Filter](),
    server: "http://localhost:4646",
  )

func makeJob(name: string): NomadJob =
  NomadJob(name: name, specPath: ("/tmp/" & name & "/job.hcl").Path, configPaths: @[])

let registry = initTargetRegistry()

suite "Target Filters":
  test "infraFilter returns jobs in config order":
    let config = makeConfig(@["garage", "valkey", "coredns"])
    let jobs =
      @[makeJob("garage"), makeJob("valkey"), makeJob("coredns"), makeJob("app")]

    let result = "infra".filter(jobs, registry, config)

    check:
      result.len == 3
      result[0].name == "garage"
      result[1].name == "valkey"
      result[2].name == "coredns"

  test "servicesFilter returns non-infra jobs sorted alphabetically":
    let config = makeConfig(@["garage"])
    let jobs = @[makeJob("zebra"), makeJob("alpha"), makeJob("garage"), makeJob("beta")]

    let result = "services".filter(jobs, registry, config)

    check:
      result.len == 3
      result[0].name == "alpha"
      result[1].name == "beta"
      result[2].name == "zebra"

  test "allFilter combines infra and services":
    let config = makeConfig(@["garage"])
    let jobs = @[makeJob("app"), makeJob("garage")]

    let result = "all".filter(jobs, registry, config)

    check:
      result.len == 2
      result[0].name == "garage" # Infra first
      result[1].name == "app" # Then services

  test "nameFilter returns exact match":
    let config = makeConfig()
    let jobs = @[makeJob("app-v1"), makeJob("app"), makeJob("api")]

    let result = "app".filter(jobs, registry, config)

    check:
      result.len == 1
      result[0].name == "app"

  test "filter raises TargetError for no matches":
    let config = makeConfig()
    let jobs = @[makeJob("app")]

    expect TargetError:
      discard "nonexistent".filter(jobs, registry, config)

  test "servicesFilter returns empty for all-infra jobs":
    let config = makeConfig(@["garage", "valkey"])
    let jobs = @[makeJob("garage"), makeJob("valkey")]

    expect TargetError:
      discard "services".filter(jobs, registry, config)

  test "infraFilter returns empty for no infra jobs":
    let config = makeConfig(@["garage"])
    let jobs = @[makeJob("app")]

    expect TargetError:
      discard "infra".filter(jobs, registry, config)

  test "allFilter handles empty job list":
    let config = makeConfig()
    let jobs: seq[NomadJob] = @[]

    expect TargetError:
      discard "all".filter(jobs, registry, config)
