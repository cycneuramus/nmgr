import std/[json, unittest]
import ../src/nmgr/nomad/jsonparser

suite "JSON Parser":
  test "parseResponse returns valid JsonNode from JSON string":
    let
      jsonStr = """{"key": "value", "number": 42}"""
      result = parseResponse(jsonStr)

    check:
      result.kind == JObject
      result.hasKey("key")
      result["key"].getStr == "value"
      result["number"].getInt == 42

  test "parseResponse returns empty object for invalid JSON":
    let jsonStr = """{invalid json"""
    let result = parseResponse(jsonStr)

    check:
      result.kind == JObject
      result.len == 0

  test "parseImages extracts images from task config":
    let
      json = parseJson(
        """
          {
            "TaskGroups": [
              {
                "Tasks": [
                  {
                    "Name": "web",
                    "Config": {
                      "image": "nginx:latest"
                    }
                  }
                ]
              }
            ]
          }
        """
      )
      result = parseImages(json)

    check:
      result.len == 1
      result[0] == "nginx:latest"

  test "parseImages extracts multiple images from task config":
    let
      json = parseJson(
        """
          {
            "TaskGroups": [
              {
                "Tasks": [
                  {
                    "Name": "web",
                    "Config": {
                      "image": "nginx:latest"
                    }
                  },
                  {
                    "Name": "db",
                    "Config": {
                      "image": "postgres:15"
                    }
                  }
                ]
              }
            ]
          }
        """
      )
      result = parseImages(json)

    check:
      result.len == 2
      result[0] == "nginx:latest"
      result[1] == "postgres:15"

  test "parseImages filters out local images":
    let
      json = parseJson(
        """
          {
            "TaskGroups": [
              {
                "Tasks": [
                  {
                    "Name": "web",
                    "Config": {
                      "image": "local.web"
                    }
                  }
                ]
              }
            ]
          }
        """
      )
      result = parseImages(json)

    check result.len == 0

  test "parseImages returns empty for missing TaskGroups":
    let
      json = parseJson("""{"key": "value"}""")
      result = parseImages(json)

    check result.len == 0

  test "parseImages returns empty for non-object taskGroup":
    let
      json = parseJson("""{"TaskGroups": ["not an object"]}""")
      result = parseImages(json)

    check result.len == 0

  test "parseImages extracts images from nested config":
    let
      json = parseJson(
        """
            {
              "TaskGroups": [
                {
                  "Tasks": [
                    {
                      "Name": "web",
                      "Config": {
                        "image": "nginx:latest",
                        "volumes": [
                          {
                            "image": "local.volume"
                          }
                        ]
                      }
                    }
                  ]
                }
              ]
            }
        """
      )
      result = parseImages(json)

    check:
      result.len == 1
      result[0] == "nginx:latest"

  test "parseTasks extracts task names from TaskGroups":
    let
      json = parseJson(
        """
          {
            "TaskGroups": [
              {
                "Tasks": [
                  {"Name": "web"},
                  {"Name": "db"}
                ]
              }
            ]
          }
        """
      )
      result = parseTasks(json)

    check:
      result.len == 2
      result[0] == "web"
      result[1] == "db"

  test "parseTasks returns empty for missing TaskGroups":
    let json = parseJson("""{}""")
    let result = parseTasks(json)

    check result.len == 0

  test "parseTasks returns empty for taskGroup without Tasks":
    let json = parseJson("""{"TaskGroups": [{}]}""")
    let result = parseTasks(json)

    check result.len == 0

  test "parseJobs extracts running job names from array":
    let
      json = parseJson(
        """
            [
              {"Name": "job1", "Status": "running"},
              {"Name": "job2", "Status": "pending"},
              {"Name": "job3", "Status": "running"}
            ]
          """
      )
      result = parseJobs(json)

    check:
      result.len == 2
      result[0] == "job1"
      result[1] == "job3"

  test "parseJobs returns empty for non-array JSON":
    let
      json = parseJson("""{"Name": "job1", "Status": "running"}""")
      result = parseJobs(json)

    check result.len == 0

  test "parseJobs filters out non-running jobs":
    let
      json = parseJson(
        """
          [
            {"Name": "job1", "Status": "stopped"},
            {"Name": "job2", "Status": "dead"}
          ]
        """
      )
      result = parseJobs(json)

    check result.len == 0

  test "parseJobs handles case-insensitive status":
    let
      json = parseJson(
        """
          [
            {"Name": "job1", "Status": "RUNNING"},
            {"Name": "job2", "Status": "Running"}
          ]
        """
      )
      result = parseJobs(json)

    check result.len == 2

  test "parseJobs skips entries without Name":
    let
      json = parseJson(
        """
          [
            {"Status": "running"},
            {"Name": "job1", "Status": "running"}
          ]
        """
      )
      result = parseJobs(json)

    check:
      result.len == 1
      result[0] == "job1"
