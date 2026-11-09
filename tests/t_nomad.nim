import std/[httpclient, json, paths, tables, unittest]
import nmgr/[errors, nomad]
import nmgr/nomad/api
import ./helpers

suite "NomadApi":
  test "adds a leading slash to the path":
    let f = newFake()
    discard f.client.api.get("v1/jobs")
    check f.requests == @[(HttpGet, testServer & "/v1/jobs")]

  test "tolerates a trailing slash on the server":
    let f = newFake()
    let api = NomadApi(server: testServer & "/", send: f.client.api.send)
    discard api.get("/v1/jobs")
    check f.requests[0][1] == testServer & "/v1/jobs"

  test "encodes query parameters":
    let f = newFake()
    discard f.client.api.delete("/v1/job/web", @[("purge", "true")])
    check f.requests == @[(HttpDelete, testServer & "/v1/job/web?purge=true")]

suite "runJob":
  test "runs the spec from its own directory":
    let f = newFake()
    f.client.runJob(mkJob("web"))
    check f.commands == @[(@["nomad", "run", "/jobs/web/web.hcl"], Path("/jobs/web"))]

  test "detach applies to services but never infra":
    let f = newFake()
    let c = f.client(detach = true)
    c.runJob(mkJob("web"))
    c.runJob(mkJob("traefik", infra = true))
    check f.commands[0][0] == @["nomad", "run", "-detach", "/jobs/web/web.hcl"]
    check f.commands[1][0] == @["nomad", "run", "/jobs/traefik/traefik.hcl"]

  test "non-zero exit raises NomadError":
    let f = newFake()
    f.exitCodes = @[1]
    expect NomadError:
      f.client.runJob(mkJob("web"))

  test "dry run executes nothing":
    let f = newFake()
    f.client(dryRun = true).runJob(mkJob("web"))
    check f.commands.len == 0

suite "stopJob":
  test "purge adds query parameter":
    let f = newFake()
    f.client(purge = true).stopJob("web")
    check f.requests == @[(HttpDelete, testServer & "/v1/job/web?purge=true")]

  test "no purge sends plain DELETE":
    let f = newFake()
    f.client.stopJob("web")
    check f.requests == @[(HttpDelete, testServer & "/v1/job/web")]

  test "dry run sends no request":
    let f = newFake()
    f.client(dryRun = true, purge = true).stopJob("web")
    check f.requests.len == 0

suite "queries":
  test "allocId picks the running allocation":
    let f = newFake()
    f.responses["/v1/job/web/allocations"] =
      $(
        %*[
          {"ID": "old", "ClientStatus": "complete"},
          {"ID": "cur", "ClientStatus": "running"},
        ]
      )
    check f.client.allocId("web") == "cur"

  test "allocId raises when nothing is running":
    let f = newFake()
    f.responses["/v1/job/web/allocations"] = "[]"
    expect NomadError:
      discard f.client.allocId("web")

  test "tasks raises when the job has none":
    let f = newFake() # default body "{}"
    expect NomadError:
      discard f.client.tasks("web")

  test "runningJobNames queries /v1/jobs":
    let f = newFake()
    f.responses["/v1/jobs"] =
      $(%*[{"Name": "web", "Status": "running"}, {"Name": "db", "Status": "dead"}])
    check f.client.runningJobNames == @["web"]

  test "liveImages are sorted":
    let f = newFake()
    f.responses["/v1/job/web"] = jobJson({"b": "redis:7", "a": "nginx:1"})
    check f.client.liveImages("web") == @["nginx:1", "redis:7"]

  test "specImages renders the spec via the nomad CLI":
    let f = newFake()
    let j = mkJob("web")
    f.specOutput[$j.specPath] = specJson({"b": "redis:7", "a": "nginx:2"})
    check f.client.specImages(j) == @["nginx:2", "redis:7"]
    check f.captures ==
      @[(@["nomad", "job", "run", "-output", "/jobs/web/web.hcl"], Path("/jobs/web"))]

  test "allocExec targets the running alloc and returns the exit code":
    let f = newFake()
    f.responses["/v1/job/web/allocations"] = allocsJson("a1")
    f.exitCodes = @[42]
    check f.client.allocExec("app", "web", @["ls", "-la"]) == 42
    check f.commands[0][0] ==
      @["nomad", "alloc", "exec", "-task", "app", "a1", "ls", "-la"]

suite "real processes":
  test "runProcess returns the exit code":
    check runProcess(@["sh", "-c", "exit 3"]) == 3

  test "captureProcess returns stdout":
    check captureProcess(@["sh", "-c", "echo hi"]) == "hi\n"

  test "captureProcess raises NomadError on failure":
    expect NomadError:
      discard captureProcess(@["sh", "-c", "echo oops >&2; exit 2"])
