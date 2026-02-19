import std/[os, strutils, tables, unittest]
import ../src/nmgr/config

proc writeTempConfig(content: string): string =
  let tempFile = getTempDir() / "nmgr_test_config_" & $getCurrentProcessId() & ".conf"
  writeFile(tempFile, content)
  return tempFile

proc cleanup(path: string) =
  if fileExists(path):
    removeFile(path)

suite "Config Parser":
  test "parse returns defaults for empty config":
    let configPath = writeTempConfig("")
    defer:
      cleanup(configPath)

    let config = parse(configPath)

    check:
      config.baseDir.string == ""
      config.infraJobs == @[""]
      config.jobConfigPatterns == @[""]
      config.ignoreDirs.len == 1 # split on empty returns array with empty string
      config.filters.len == 0
      config.server == "http://127.0.0.1:4646" # default

  test "parse reads general section":
    let configPath = writeTempConfig(
      """
      [general]
      base_dir = "/opt/nomad"
      infra_jobs = "garage valkey coredns"
      job_config_patterns = ".env .conf"
      ignore_dirs = ".git tmp"
      nomad_url = "http://nomad.local:4646"
      """.dedent()
    )
    defer:
      cleanup(configPath)

    let config = parse(configPath)

    check:
      config.baseDir.string == "/opt/nomad"
      config.infraJobs == @["garage", "valkey", "coredns"]
      config.jobConfigPatterns == @[".env", ".conf"]
      config.ignoreDirs.len == 2
      config.ignoreDirs[0].string == ".git"
      config.ignoreDirs[1].string == "tmp"
      config.server == "http://nomad.local:4646"

  test "parse expands tilde in base_dir":
    let configPath = writeTempConfig(
      """
      [general]
      base_dir = "~/nomad/jobs"
      """.dedent()
    )
    defer:
      cleanup(configPath)

    let config = parse(configPath)

    check:
      config.baseDir.string != ""
      not config.baseDir.string.contains("~")

  test "parse handles single-value lists":
    let configPath = writeTempConfig(
      """
      [general]
      infra_jobs = "garage"
      job_config_patterns = ".env"
      """.dedent()
    )
    defer:
      cleanup(configPath)

    let config = parse(configPath)

    check:
      config.infraJobs == @["garage"]
      config.jobConfigPatterns == @[".env"]

  test "parse handles empty list values":
    let configPath = writeTempConfig(
      """
      [general]
      infra_jobs =
      """.dedent()
    )
    defer:
      cleanup(configPath)

    let config = parse(configPath)

    check config.infraJobs == @[""]

  test "parse reads filter sections":
    let configPath = writeTempConfig(
      """
      [general]
      base_dir = "/tmp"

      [filter.nas]
      pattern = "/mnt/nas"

      [filter.db]
      pattern = "15432"
      extended_search = true
      exclude_infra = false
      """.dedent()
    )
    defer:
      cleanup(configPath)

    let config = parse(configPath)

    check:
      config.filters.len == 2
      config.filters.hasKey("nas")
      config.filters.hasKey("db")

    let nasFilter = config.filters["nas"]
    check:
      nasFilter.name == "nas"
      nasFilter.pattern == "/mnt/nas"
      nasFilter.extendedSearch == false
      nasFilter.excludeInfra == false

    let dbFilter = config.filters["db"]
    check:
      dbFilter.name == "db"
      dbFilter.pattern == "15432"
      dbFilter.extendedSearch == true
      dbFilter.excludeInfra == false

  test "parse ignores non-filter sections":
    let configPath = writeTempConfig(
      """
      [general]
      base_dir = "/tmp"

      [random_section]
      key = "value"

      [another.section]
      foo = "bar"
      """.dedent()
    )
    defer:
      cleanup(configPath)

    let config = parse(configPath)

    check config.filters.len == 0
