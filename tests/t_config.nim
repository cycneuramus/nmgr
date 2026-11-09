import std/[appdirs, dirs, paths, tables, tempfiles, unittest]
import nmgr/[config, errors]

let dir = Path(createTempDir("nmgr_config_", ""))

proc configFrom(content: string): Config =
  let path = dir / Path("config")
  writeFile($path, content)
  parseConfig(path)

suite "parseConfig":
  test "reads general settings and filters":
    let cfg = configFrom(
      """
[general]
base_dir = "~/nomad"
ignore_dirs = "archive  tmp"
infra_jobs = "traefik consul"
job_config_patterns = ".env config."
nomad_url = "http://nomad.lan:4646"

[filter.web]
pattern = "traefik.enable=true"
extended_search = true
exclude_infra = true

[filter.db]
pattern = "postgres"
"""
    )
    check cfg.baseDir == getHomeDir() / Path("nomad")
    check cfg.ignoreDirs == @[Path("archive"), Path("tmp")]
    check cfg.infraJobs == @["traefik", "consul"]
    check cfg.jobConfigPatterns == @[".env", "config."]
    check cfg.server == "http://nomad.lan:4646"
    check cfg.filters.len == 2
    check cfg.filters["web"] ==
      Filter(
        name: "web",
        pattern: "traefik.enable=true",
        extendedSearch: true,
        excludeInfra: true,
      )
    check cfg.filters["db"] == Filter(name: "db", pattern: "postgres")

  test "applies defaults for missing keys":
    let cfg = configFrom("[general]\nbase_dir = \"/srv/jobs\"\n")
    check cfg.baseDir == Path("/srv/jobs")
    check cfg.server == "http://127.0.0.1:4646"
    check cfg.ignoreDirs.len == 0
    check cfg.infraJobs.len == 0
    check cfg.filters.len == 0

  test "default config parses":
    const shipped = staticRead("../data/config")
    let cfg = configFrom(shipped)
    check cfg.server.len > 0

  test "missing file raises ConfigError":
    expect ConfigError:
      discard parseConfig(dir / Path("does-not-exist"))

removeDir(dir)
