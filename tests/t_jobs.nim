import std/[algorithm, dirs, paths, sequtils, tempfiles, unittest]
import nmgr/[config, errors, jobs]
import ./helpers

suite "definedJobs":
  var root: Path
  setup:
    root = Path(createTempDir("nmgr_jobs_", ""))
  teardown:
    removeDir(root)

  test "discovers jobs one directory deep":
    writeTree(
      root,
      {
        "web/web.hcl": "job \"web\" {\n}",
        "db/db.nomad": "# postgres\n  job   \"postgres\" {\n}",
        "traefik/traefik.hcl": "job \"traefik\" {}",
        "web/README.md": "job \"not-a-spec\" {}",
        "toplevel.hcl": "job \"toplevel\" {}",
        "archive/old.hcl": "job \"old\" {}",
        "broken/broken.hcl": "variable \"job\" {}",
      },
    )
    let cfg =
      Config(baseDir: root, ignoreDirs: @[Path("archive")], infraJobs: @["traefik"])
    let found = definedJobs(cfg).sortedByIt(it.name)

    check found.mapIt(it.name) == @["postgres", "traefik", "web"]
    check found.mapIt(it.isInfra) == @[false, true, false]
    check found.allIt(not it.isRunning)
    check found[2].specPath == root / Path("web/web.hcl")

  test "missing base dir raises JobError":
    expect JobError:
      discard definedJobs(Config(baseDir: root / Path("nope")))
