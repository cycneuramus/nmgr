import std/[dirs, httpclient, json, paths, tables, uri]
import nmgr/[jobs, nomad]
import nmgr/nomad/api

const testServer* = "http://nomad.test:4646"

type
  ApiCall* = (HttpMethod, string)
  CmdCall* = (seq[string], Path)
  FakeNomad* = ref object
    responses*: Table[string, string]
    requests*: seq[ApiCall]
    commands*: seq[CmdCall]
    captures*: seq[CmdCall]
    exitCodes*: seq[int]
    specOutput*: Table[string, string]

proc newFake*(): FakeNomad =
  FakeNomad()

proc client*(f: FakeNomad, dryRun = false, detach = false, purge = false): NomadClient =
  proc fakeSend(verb: HttpMethod, url: string): string =
    f.requests.add((verb, url))
    f.responses.getOrDefault(parseUri(url).path, "{}")

  proc fakeRun(cmd: seq[string], workingDir: Path): int =
    f.commands.add((cmd, workingDir))
    if f.exitCodes.len > 0:
      result = f.exitCodes[0]
      f.exitCodes.delete(0)

  proc fakeCapture(cmd: seq[string], workingDir: Path): string =
    f.captures.add((cmd, workingDir))
    f.specOutput.getOrDefault(cmd[^1], """{"Job": {}}""")

  NomadClient(
    dryRun: dryRun,
    detach: detach,
    purge: purge,
    api: NomadApi(server: testServer, send: fakeSend),
    runCmd: fakeRun,
    captureCmd: fakeCapture,
  )

proc mkJob*(name: string, running = true, infra = false): NomadJob =
  NomadJob(
    name: name,
    specPath: Path("/jobs") / Path(name) / Path(name & ".hcl"),
    isRunning: running,
    isInfra: infra,
  )

proc jobNode(tasks: openArray[(string, string)]): JsonNode =
  ## One task group; each task is (name, image)
  var ts = newJArray()
  for (name, image) in tasks:
    ts.add(%*{"Name": name, "Config": {"image": image}})
  %*{"TaskGroups": [{"Tasks": ts}]}

proc jobJson*(tasks: openArray[(string, string)]): string =
  $jobNode(tasks)

proc specJson*(tasks: openArray[(string, string)]): string =
  $(%*{"Job": jobNode(tasks)})

proc allocsJson*(id: string): string =
  $(%*[{"ID": id, "ClientStatus": "running"}])

proc writeTree*(root: Path, files: openArray[(string, string)]) =
  for (rel, content) in files:
    let path = root / Path(rel)
    createDir(path.parentDir)
    writeFile($path, content)
