import std/[envvars, httpclient, sequtils, tables, unittest]
import nmgr/[action, errors]
import ./helpers

suite "up":
  test "starts jobs in order":
    let f = newFake()
    acUp.perform(
      @[
        mkJob("traefik", running = false, infra = true),
        mkJob("web"),
        mkJob("api", running = false),
      ],
      f.client,
    )
    check f.commands.mapIt(it[0][^1]) ==
      @["/jobs/traefik/traefik.hcl", "/jobs/web/web.hcl", "/jobs/api/api.hcl"]

suite "down":
  test "stops running jobs in reverse order (infra last)":
    let f = newFake()
    acDown.perform(
      @[
        mkJob("traefik", infra = true),
        mkJob("api"),
        mkJob("web", running = false),
        mkJob("zeta"),
      ],
      f.client,
    )
    check f.requests ==
      @[
        (HttpDelete, testServer & "/v1/job/zeta"),
        (HttpDelete, testServer & "/v1/job/api"),
        (HttpDelete, testServer & "/v1/job/traefik"),
      ]

suite "reconcile":
  test "restarts only running services whose images changed":
    let f = newFake()
    for (name, live, spec) in [
      ("same", "nginx:1", "nginx:1"),
      ("changed", "nginx:1", "nginx:2"),
      ("infra", "traefik:2", "traefik:3"),
      ("stopped", "x:1", "x:2"),
    ]:
      f.responses["/v1/job/" & name] = jobJson({"t": live})
      f.specOutput["/jobs/" & name & "/" & name & ".hcl"] = specJson({"t": spec})

    acReconcile.perform(
      @[
        mkJob("same"),
        mkJob("changed"),
        mkJob("infra", infra = true),
        mkJob("stopped", running = false),
      ],
      f.client,
    )
    check f.commands.mapIt(it[0]) == @[@["nomad", "run", "/jobs/changed/changed.hcl"]]

suite "shell":
  proc shellFake(exitCodes: seq[int]): FakeNomad =
    result = newFake()
    result.responses["/v1/job/web"] = jobJson({"app": "nginx"}) # single task: no prompt
    result.responses["/v1/job/web/allocations"] = allocsJson("a1")
    result.exitCodes = exitCodes

  test "uses bash when available":
    let f = shellFake(@[0])
    acShell.perform(@[mkJob("web")], f.client)
    check f.commands.mapIt(it[0][^1]) == @["bash"]

  test "a non-zero user exit is not treated as a missing shell":
    let f = shellFake(@[1])
    acShell.perform(@[mkJob("web")], f.client)
    check f.commands.len == 1

  test "falls back to sh":
    let f = shellFake(@[127, 0])
    acShell.perform(@[mkJob("web")], f.client)
    check f.commands.mapIt(it[0][^1]) == @["bash", "sh"]
    check f.commands[1][0] == @["nomad", "alloc", "exec", "-task", "app", "a1", "sh"]

  test "raises when no shell exists":
    let f = shellFake(@[127, 126])
    expect NomadError:
      acShell.perform(@[mkJob("web")], f.client)

suite "edit":
  test "requires $EDITOR":
    delEnv("EDITOR")
    expect NmgrError:
      acEdit.perform(@[mkJob("web")], newFake().client)
