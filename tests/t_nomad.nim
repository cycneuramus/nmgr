import std/[unittest]
import ../src/nmgr/nomad

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
