import std/[options, strutils, unittest]
import ../src/nmgr/nomad/hclparser

suite "HCL Parser":
  test "extract job name from simple job block":
    let spec = """
      job "test-job" {
        datacenters = ["dc1"]

        group "test-group" {
          task "test-task" {
            driver = "docker"
          }
        }
      }
      """.dedent()

    let parsed = parseHcl(spec)
    let jobName = parsed.getJobName()

    check:
      jobName.isSome
      jobName.get == "test-job"

  test "handle multiple root blocks":
    let spec = """
      locals {
        image = "nginx:latest"
      }

      job "multi-block-job" {
        datacenters = ["dc1"]
      }
      """.dedent()

    let parsed = parseHcl(spec)
    check parsed.rootBlocks.len == 2

  test "getJobName returns none when no job block":
    let spec = """
      locals {
        image = "nginx:latest"
      }
      """.dedent()

    let parsed = parseHcl(spec)
    let jobName = parsed.getJobName()
    check jobName.isNone

  test "extract task names from job":
    let spec = """
      job "task-test" {
        group "group1" {
          task "task-one" {
            driver = "docker"
          }
          task "task-two" {
            driver = "exec"
          }
        }
      }
      """.dedent()

    let parsed = parseHcl(spec)
    let jobBlocks = parsed.getBlocksOfType("job")
    check jobBlocks.len == 1

    let tasks = jobBlocks[0].getTasks()
    check:
      tasks.len == 2
      tasks.contains("task-one")
      tasks.contains("task-two")

  test "strip line comments":
    let spec = """
      job "comment-test" {
        # This is a comment
        datacenters = ["dc1"] // inline comment
      }
      """.dedent()

    let parsed = parseHcl(spec)
    let jobName = parsed.getJobName()

    check:
      jobName.isSome
      jobName.get == "comment-test"

  test "handle empty input":
    let parsed = parseHcl("")
    check parsed.rootBlocks.len == 0

  test "extract image from locals block":
    let spec = """
      locals {
        image = "redis:7"
      }

      job "image-test" {
        datacenters = ["dc1"]
      }
      """.dedent()

    let parsed = parseHcl(spec)
    let images = parsed.getImages()

    check:
      images.len == 1
      images[0] == "redis:7"

  test "extract images from locals map":
    let spec = """
      locals {
        image = {
          frontend = "nginx:alpine"
          backend = "node:18"
        }
      }
      """.dedent()

    let parsed = parseHcl(spec)
    let images = parsed.getImages()

    check:
      images.len == 2
      images.contains("nginx:alpine")
      images.contains("node:18")

  test "skip local variable references":
    let spec = """
      locals {
        image = "local.custom-image"
      }
      """.dedent()

    let parsed = parseHcl(spec)
    let images = parsed.getImages()

    check images.len == 0

  test "handle nested blocks":
    let spec = """
      job "nested-test" {
        group "web" {
          network {
            mode = "bridge"
          }
          task "server" {
            driver = "docker"
          }
        }
      }
      """.dedent()

    let parsed = parseHcl(spec)
    let jobBlocks = parsed.getBlocksOfType("job")

    check:
      jobBlocks.len == 1
      jobBlocks[0].children.len == 1
      jobBlocks[0].children[0].children.len == 2
