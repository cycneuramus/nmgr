import std/[algorithm, json, unittest]
import nmgr/errors
import nmgr/nomad/jsonparser

suite "parseNomadJson":
  test "parses valid JSON":
    check parseNomadJson("""{"ID": "x"}""")["ID"].getStr == "x"

  test "wraps parse failures in NomadError":
    for body in ["", "not json", """{"unterminated": """]:
      expect NomadError:
        discard parseNomadJson(body)

suite "job inspection":
  let job =
    %*{
      "TaskGroups": [
        {
          "Tasks": [
            {"Name": "app", "Config": {"image": "nginx:1.25"}},
            {"Name": "sidecar", "Config": {"image": "nginx:1.25"}},
          ]
        },
        {
          "Tasks": [
            {
              "Name": "db",
              "Config": {"image": "postgres:16", "extra": [{"image": "busybox"}]},
            },
            {"Name": "raw"},
            {"Name": "", "Config": {"command": "/bin/true"}},
          ]
        },
      ]
    }

  test "images: collects nested image keys across groups, deduplicated":
    check job.images.sorted == @["busybox", "nginx:1.25", "postgres:16"]

  test "images/taskNames: tolerate jobs without task groups":
    check newJObject().images.len == 0
    check newJObject().taskNames.len == 0

  test "taskNames: keeps order, skips unnamed tasks":
    check job.taskNames == @["app", "sidecar", "db", "raw"]

suite "allocations and job lists":
  test "runningAllocId returns first running allocation":
    let allocs =
      %*[
        {"ID": "old", "ClientStatus": "complete"},
        {"ID": "cur", "ClientStatus": "running"},
        {"ID": "new", "ClientStatus": "running"},
      ]
    check allocs.runningAllocId == "cur"

  test "runningAllocId is empty when nothing runs":
    check (%*[{"ID": "old", "ClientStatus": "failed"}]).runningAllocId == ""
    check newJArray().runningAllocId == ""

  test "runningJobNames filters by status":
    let jobs =
      %*[
        {"Name": "web", "Status": "running"},
        {"Name": "db", "Status": "dead"},
        {"Name": "api", "Status": "pending"},
        {"Name": "", "Status": "running"},
      ]
    check jobs.runningJobNames == @["web"]
