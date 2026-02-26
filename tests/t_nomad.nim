import std/[os, paths, unittest]
import ../src/nmgr/[config, nomad, nomad/api]

suite "Nomad Client":
  test "extractImages parses HCL and extracts images from locals":
    let
      hcl = """
          locals {
            image = "nginx:latest"
          }
        """
      result = extractImages(hcl)

    check:
      result.len == 1
      result[0] == "nginx:latest"

  test "extractImages extracts images from config block":
    let
      hcl = """
          config {
            image = "redis:7"
          }
        """
      result = extractImages(hcl)

    check:
      result.len == 1
      result[0] == "redis:7"

  test "extractImages returns multiple images":
    let
      hcl = """
          locals {
            image = "nginx:latest"
          }

          config {
            image = "redis:7"
          }
        """
      result = extractImages(hcl)

    check:
      result.len == 2
      result[0] == "nginx:latest"
      result[1] == "redis:7"

  test "extractImages filters out local images":
    let
      hcl = """
          locals {
            image = "local.web"
          }
        """
      result = extractImages(hcl)

    check result.len == 0

  test "extractImages handles empty HCL":
    let
      hcl = ""
      result = extractImages(hcl)

    check result.len == 0

  test "extractImages extracts from map in locals":
    let
      hcl = """
          locals {
            image = {
              web = "nginx:latest",
              db = "postgres:15"
            }
          }
        """
      result = extractImages(hcl)

    check result.len == 2

  test "getSpecImage returns sorted images":
    let
      hcl = """
          locals {
            image = "zebra:latest"
          }

          config {
            image = "alpha:latest"
          }
        """
      tempDir = "tests/temp".Path
      specPath = tempDir / "test.nomad".Path

    createDir($tempDir)
    writeFile($specPath, hcl)

    defer:
      removeFile($specPath)
      removeDir($tempDir)

    let nomadClient = NomadClient(config: Config(baseDir: "tests".Path))
    let result = nomadClient.getSpecImage(specPath)

    check:
      result.len == 2
      result[0] == "alpha:latest"
      result[1] == "zebra:latest"

  test "getLiveImage returns sorted images":
    let
      mockJson = """
        {
          "TaskGroups": [{
            "Tasks": [
              {"Name": "task1", "Config": {"image": "zebra:latest"}},
              {"Name": "task2", "Config": {"image": "alpha:latest"}}
            ]
          }]
        }
      """
      api = NomadApi(
        server: "http://localhost:4646",
        caller: proc(httpMethod, endpoint: string): string =
          mockJson,
      )
      nomadClient = NomadClient(config: Config(baseDir: "tests".Path), api: api)
      result = nomadClient.getLiveImage("test-job")

    check:
      result.len == 2
      result[0] == "alpha:latest"
      result[1] == "zebra:latest"
