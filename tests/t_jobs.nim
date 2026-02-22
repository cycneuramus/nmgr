import std/[os, paths, strutils, tables, unittest]
import ../src/nmgr/[config, errors, jobs]

func makeFilter(pattern: string, extendedSearch = false, excludeInfra = false): Filter =
  Filter(
    name: "test",
    pattern: pattern,
    extendedSearch: extendedSearch,
    excludeInfra: excludeInfra,
  )

func makeConfig(jobConfigPatterns: seq[string] = @[]): Config =
  Config(
    baseDir: "/tmp".Path,
    infraJobs: @[],
    filters: initTable[string, Filter](),
    jobConfigPatterns: jobConfigPatterns,
    server: "http://localhost:4646",
  )

suite "Job Operations":
  test "readSpec returns file content":
    let tempDir = getTempDir() / "nmgr_test_" & $getCurrentProcessId()
    createDir(tempDir)

    let specFile = tempDir / "test.hcl"
    let content = """
      job "test-job" {
        datacenters = ["dc1"]
      }
      """.dedent()
    writeFile(specFile, content)

    defer:
      removeFile(specFile)
      removeDir(tempDir)

    let result = readSpec(specFile)

    check result == content

  test "readSpec raises JobError for missing file":
    expect JobError:
      discard readSpec("/nonexistent/path/job.hcl")

  test "matchesFilter finds pattern in file":
    let tempDir = getTempDir() / "nmgr_filter_test"
    createDir(tempDir)

    let testFile = tempDir / "config.env"
    writeFile(testFile, "DATABASE_URL=postgres://localhost\nAPI_KEY=secret123")

    defer:
      removeFile(testFile)
      removeDir(tempDir)

    let job = NomadJob(name: "test", specPath: testFile.Path, configPaths: @[])
    let filter = makeFilter("DATABASE_URL")
    let config = makeConfig()

    let result = job.matchesFilter(filter, @[testFile.Path], config)

    check result == true

  test "matchesFilter returns false when pattern not found":
    let tempDir = getTempDir() / "nmgr_filter_test2"
    createDir(tempDir)

    let testFile = tempDir / "config.env"
    writeFile(testFile, "CACHE_URL=redis://localhost")

    defer:
      removeFile(testFile)
      removeDir(tempDir)

    let job = NomadJob(name: "test", specPath: testFile.Path, configPaths: @[])
    let filter = makeFilter("DATABASE_URL")
    let config = makeConfig()

    let result = job.matchesFilter(filter, @[testFile.Path], config)

    check result == false

  test "matchesFilter checks multiple paths":
    let tempDir = getTempDir() / "nmgr_multi_test"
    createDir(tempDir)

    let file1 = tempDir / "config1.env"
    let file2 = tempDir / "config2.env"
    writeFile(file1, "KEY1=value1")
    writeFile(file2, "KEY2=value2")

    defer:
      removeFile(file1)
      removeFile(file2)
      removeDir(tempDir)

    let job = NomadJob(name: "test", specPath: file1.Path, configPaths: @[file2.Path])
    let filter = makeFilter("KEY2")
    let config = makeConfig()

    let result = job.matchesFilter(filter, @[file1.Path, file2.Path], config)

    check result == true

  test "matchesFilter skips non-existent files":
    let job =
      NomadJob(name: "test", specPath: "/nonexistent/spec.hcl".Path, configPaths: @[])
    let filter = makeFilter("anything")
    let config = makeConfig()

    let result = job.matchesFilter(filter, newSeq[Path](), config)

    check result == false

  test "findConfigs discovers files by pattern":
    let tempDir = getTempDir() / "nmgr_find_test"
    createDir(tempDir)

    let envFile = tempDir / "prod.env"
    let confFile = tempDir / "app.conf"
    let otherFile = tempDir / "readme.txt"
    writeFile(envFile, "ENV=prod")
    writeFile(confFile, "setting=value")
    writeFile(otherFile, "nothing")

    defer:
      removeFile(envFile)
      removeFile(confFile)
      removeFile(otherFile)
      removeDir(tempDir)

    let result = findConfigs(tempDir.Path, @[".env", ".conf"])

    check:
      result.len == 2
      envFile.Path in result
      confFile.Path in result

  test "findConfigs returns empty for no matches":
    let tempDir = getTempDir() / "nmgr_empty_test"
    createDir(tempDir)

    let txtFile = tempDir / "file.txt"
    writeFile(txtFile, "content")

    defer:
      removeFile(txtFile)
      removeDir(tempDir)

    let result = findConfigs(tempDir.Path, @[".env", ".conf"])

    check result.len == 0

  test "findConfigs returns empty for empty directory":
    let tempDir = getTempDir() / "nmgr_empty_dir"
    createDir(tempDir)

    defer:
      removeDir(tempDir)

    let result = findConfigs(tempDir.Path, @[".env"])

    check result.len == 0

  test "getDefinedJobs raises JobError for non-existent base dir":
    let baseDir = getTempDir() / "nmgr_nonexistent_" & $getCurrentProcessId()
    if dirExists(baseDir):
      removeDir(baseDir)

    let configWithBadPath = Config(
      baseDir: baseDir.Path,
      infraJobs: @[],
      filters: initTable[string, Filter](),
      jobConfigPatterns: @[],
      server: "http://localhost:4646",
    )

    expect JobError:
      discard getDefinedJobs(configWithBadPath)

  test "getDefinedJobs discovers jobs from directory structure":
    let baseDir = getTempDir() / "nmgr_jobs_test"
    let jobDir = baseDir / "webapp"
    createDir(jobDir)

    let specFile = jobDir / "job.hcl"
    let specContent = """
      job "web-app" {
        datacenters = ["dc1"]

        group "web" {
          task "server" {
            driver = "docker"
          }
        }
      }
      """.dedent()
    writeFile(specFile, specContent)

    defer:
      removeFile(specFile)
      removeDir(jobDir)
      removeDir(baseDir)

    let config = Config(
      baseDir: baseDir.Path,
      infraJobs: @[],
      filters: initTable[string, Filter](),
      jobConfigPatterns: @[],
      server: "http://localhost:4646",
    )

    let result = getDefinedJobs(config)

    check:
      result.len == 1
      result[0].name == "web-app"
      result[0].specPath == specFile.Path

  test "getDefinedJobs ignores non-spec files":
    let baseDir = getTempDir() / "nmgr_ignore_test"
    let jobDir = baseDir / "myjob"
    createDir(jobDir)

    let hclFile = jobDir / "job.hcl"
    let txtFile = jobDir / "readme.txt"
    writeFile(hclFile, "job \"myjob\" {}")
    writeFile(txtFile, "readme content")

    defer:
      removeFile(hclFile)
      removeFile(txtFile)
      removeDir(jobDir)
      removeDir(baseDir)

    let config = Config(
      baseDir: baseDir.Path,
      infraJobs: @[],
      filters: initTable[string, Filter](),
      jobConfigPatterns: @[],
      server: "http://localhost:4646",
    )

    let result = getDefinedJobs(config)

    check:
      result.len == 1
      result[0].name == "myjob"

  test "getDefinedJobs discovers config files":
    let baseDir = getTempDir() / "nmgr_config_test"
    let jobDir = baseDir / "api"
    createDir(jobDir)

    let specFile = jobDir / "api.nomad"
    let envFile = jobDir / "prod.env"
    writeFile(specFile, "job \"api-server\" {}")
    writeFile(envFile, "ENV=production")

    defer:
      removeFile(specFile)
      removeFile(envFile)
      removeDir(jobDir)
      removeDir(baseDir)

    let config = Config(
      baseDir: baseDir.Path,
      infraJobs: @[],
      filters: initTable[string, Filter](),
      jobConfigPatterns: @[".env"],
      server: "http://localhost:4646",
    )

    let result = getDefinedJobs(config)

    check:
      result.len == 1
      result[0].configPaths.len == 1
      result[0].configPaths[0] == envFile.Path

  test "getDefinedJobs ignores configured ignore dirs":
    let baseDir = getTempDir() / "nmgr_ignoredir_test"
    let jobDir = baseDir / "app"
    let ignoreDir = baseDir / ".git"
    createDir(jobDir)
    createDir(ignoreDir)

    let appSpec = jobDir / "app.hcl"
    let gitSpec = ignoreDir / "config.hcl"
    writeFile(appSpec, "job \"app\" {}")
    writeFile(gitSpec, "job \"git-config\" {}")

    defer:
      removeFile(appSpec)
      removeFile(gitSpec)
      removeDir(jobDir)
      removeDir(ignoreDir)
      removeDir(baseDir)

    let config = Config(
      baseDir: baseDir.Path,
      ignoreDirs: @[".git".Path],
      infraJobs: @[],
      filters: initTable[string, Filter](),
      jobConfigPatterns: @[],
      server: "http://localhost:4646",
    )

    let result = getDefinedJobs(config)

    check:
      result.len == 1
      result[0].name == "app"
