import std/[httpclient, strutils, unittest]
import ../src/nmgr/nomad/api

suite "Nomad API":
  test "newHttp creates client with JSON content type":
    let client = newHttp()
    check:
      client.headers.hasKey("Content-Type")
      client.headers.getOrDefault("Content-Type") == "application/json"

  test "get calls use GET method":
    var
      api = NomadApi(server: "http://localhost:4646")
      called = false

    api.caller = proc(httpMethod, endpoint: string): string =
      called = true
      check:
        httpMethod == "GET"
        endpoint == "http://localhost:4646/v1/job/myjob"
      return "{}"

    discard api.get("/v1/job/myjob")

    check called

  test "get includes query parameters in endpoint":
    var
      api = NomadApi(server: "http://localhost:4646")
      capturedEndpoint = ""

    api.caller = proc(httpMethod, endpoint: string): string =
      capturedEndpoint = endpoint
      return "{}"

    let query = @[("namespace", "default")]
    discard api.get("/v1/jobs", query)

    check capturedEndpoint.contains("namespace")

  test "delete calls use DELETE method":
    var
      api = NomadApi(server: "http://localhost:4646")
      called = false

    api.caller = proc(httpMethod, endpoint: string): string =
      called = true
      check httpMethod == "DELETE"
      check endpoint == "http://localhost:4646/v1/job/myjob"
      return "{}"

    discard api.delete("/v1/job/myjob")

    check called

  test "delete includes query parameters in endpoint":
    var
      api = NomadApi(server: "http://localhost:4646")
      capturedEndpoint = ""

    api.caller = proc(httpMethod, endpoint: string): string =
      capturedEndpoint = endpoint
      return "{}"

    let query = @[("purge", "true")]
    discard api.delete("/v1/job/myjob", query)

    check capturedEndpoint.contains("purge")

  test "get returns body from caller":
    var api = NomadApi(server: "http://localhost:4646")
    api.caller = proc(httpMethod, endpoint: string): string =
      return """{"key": "value"}"""

    let result = api.get("/v1/jobs")
    check result == """{"key": "value"}"""

  test "delete returns body from caller":
    var api = NomadApi(server: "http://localhost:4646")
    api.caller = proc(httpMethod, endpoint: string): string =
      return """{"Status": "OK"}"""

    let result = api.delete("/v1/job/myjob")
    check result == """{"Status": "OK"}"""
