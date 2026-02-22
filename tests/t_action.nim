import std/[paths, tables, unittest]
import ../src/nmgr/[action, config, jobs, nomad, registry]

const actions =
  @["up", "down", "find", "list", "image", "logs", "exec", "shell", "reconcile", "edit"]

func makeConfig(): Config =
  Config(
    baseDir: "/tmp".Path,
    infraJobs: @[],
    filters: initTable[string, Filter](),
    server: "http://localhost:4646",
  )

func makeJob(name: string): NomadJob =
  NomadJob(name: name, specPath: ("/tmp/" & name & "/job.hcl").Path, configPaths: @[])

suite "Action Handler":
  test "initActionRegistry creates registry with all actions":
    let registry = initActionRegistry()

    check registry.len == actions.len
    for a in actions:
      check registry.hasKey(a)

  test "handle raises UnknownActionError for unknown action":
    let
      registry = initActionRegistry()
      jobs = @[makeJob("app")]
      config = makeConfig()
      nomadClient = NomadClient(config: config)

    expect UnknownActionError:
      handle("nonexistent", registry, jobs, nomadClient, config)

  test "handle calls handler for known action":
    var
      handlerCalled = false
      receivedJobs: seq[NomadJob] = @[]
      registry = initActionRegistry()

    registry.add(
      "testAction",
      proc(jobs: seq[NomadJob], nomad: NomadClient, config: Config) =
        handlerCalled = true
        receivedJobs = jobs,
    )

    let
      jobs = @[makeJob("app"), makeJob("db")]
      config = makeConfig()
      nomadClient = NomadClient(config: config)

    handle("testAction", registry, jobs, nomadClient, config)

    check:
      handlerCalled == true
      receivedJobs.len == 2
      receivedJobs[0].name == "app"
      receivedJobs[1].name == "db"

  test "handle passes config to handler":
    var receivedInfraJobs: seq[string] = @[]

    var registry = initActionRegistry()
    registry.add(
      "testAction",
      proc(jobs: seq[NomadJob], nomad: NomadClient, config: Config) =
        receivedInfraJobs = config.infraJobs,
    )

    let jobs = @[makeJob("app")]
    var config = makeConfig()
    config.infraJobs = @["infra"]
    let nomadClient = NomadClient(config: config)

    handle("testAction", registry, jobs, nomadClient, config)

    check receivedInfraJobs == @["infra"]

  test "handle passes nomad client to handler":
    var receivedDryRun = false

    var registry = initActionRegistry()
    registry.add(
      "testAction",
      proc(jobs: seq[NomadJob], nomad: NomadClient, config: Config) =
        receivedDryRun = nomad.dryRun,
    )

    let
      jobs = @[makeJob("app")]
      config = makeConfig()
      nomadClient = NomadClient(config: config, dryRun: true)

    handle("testAction", registry, jobs, nomadClient, config)

    check receivedDryRun == true
