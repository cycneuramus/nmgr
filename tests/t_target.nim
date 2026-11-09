import std/[dirs, paths, sequtils, tables, tempfiles, unittest]
import nmgr/[config, errors, jobs, target]
import ./helpers

let root = Path(createTempDir("nmgr_target_", ""))
writeTree(
  root,
  {
    "consul/consul.hcl": "job \"consul\" {}",
    "traefik/traefik.hcl": "job \"traefik\" {\n  tags = [\"traefik.enable=true\"]\n}",
    "web/web.hcl": "job \"web\" {\n  tags = [\"traefik.enable=true\"]\n}",
    "api/api.hcl": "job \"api\" {}",
    "api/api.env": "TAGS=traefik.enable=true",
    "db/db.hcl": "job \"db\" {}",
    "db/notes.txt": "traefik.enable=true", # not a config pattern; must be ignored
  },
)

var cfg = Config(
  baseDir: root,
  infraJobs: @["traefik", "consul"], # deliberately not alphabetical
  jobConfigPatterns: @[".env"],
)
cfg.filters["proxied"] =
  Filter(name: "proxied", pattern: "traefik.enable=true", excludeInfra: true)
cfg.filters["proxied-all"] =
  Filter(name: "proxied-all", pattern: "traefik.enable=true", extendedSearch: true)
cfg.filters["empty"] = Filter(name: "empty", pattern: "no-such-string")

let allJobs = definedJobs(cfg)

proc names(targets: seq[string], adHoc = false): seq[string] =
  targets.resolve(allJobs, cfg, adHoc).mapIt(it.name)

suite "builtin targets":
  test "infra keeps config order":
    check names(@["infra"]) == @["traefik", "consul"]

  test "services are sorted and exclude infra":
    check names(@["services"]) == @["api", "db", "web"]

  test "all is infra first, then services":
    check names(@["all"]) == @["traefik", "consul", "api", "db", "web"]

suite "names and dedup":
  test "job by name":
    check names(@["db"]) == @["db"]

  test "overlapping targets are deduplicated, first occurrence wins":
    check names(@["web", "all", "web"]) == @["web", "traefik", "consul", "api", "db"]

  test "unknown target raises TargetError":
    expect TargetError:
      discard names(@["nope"])

suite "filters":
  test "spec-only search honours excludeInfra":
    check names(@["proxied"]) == @["web"]

  test "extended search includes matching config files only":
    check names(@["proxied-all"]) == @["api", "traefik", "web"]

  test "filter with no matches raises TargetError":
    expect TargetError:
      discard names(@["empty"])

  test "ad hoc search matches spec contents":
    check names(@["traefik.enable"], adHoc = true) == @["traefik", "web"]

  test "ad hoc search with no matches is not an error":
    check names(@["zzz"], adHoc = true).len == 0

removeDir(root)
