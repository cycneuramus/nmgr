import std/[os, paths, strformat, strutils]
import ./[errors, jobs, logging, nomad]

type Action* = enum
  acUp = "up"
  acDown = "down"
  acFind = "find"
  acList = "list"
  acImage = "image"
  acLogs = "logs"
  acExec = "exec"
  acShell = "shell"
  acReconcile = "reconcile"
  acEdit = "edit"

const
  singleJobActions* = {acLogs, acExec, acShell, acEdit}
  offlineActions* = {acFind, acList, acEdit}

using
  jobs: seq[NomadJob]
  nomad: NomadClient

proc selectTask(nomad; job: NomadJob): string =
  let tasks = nomad.tasks(job.name)
  if tasks.len == 1:
    return tasks[0]

  echo fmt"Tasks for job {job.name}:"
  for idx, task in tasks:
    echo fmt"{idx + 1}. {task}"

  while true:
    stdout.write "\nSelect a task (number): "
    let inputLine = readLine(stdin)
    try:
      let choice = parseInt(inputLine)
      if choice in 1 .. tasks.len:
        return tasks[choice - 1]
      echo "Invalid choice. Please enter a valid number."
    except CatchableError:
      echo "Please enter a valid number."

proc up(jobs, nomad) =
  for job in jobs:
    if job.isRunning:
      debug fmt"Job {job.name} is already running"
      continue

    debug fmt"Bringing job UP: {job.name}"
    nomad.runJob(job)

proc down(jobs, nomad) =
  for job in jobs:
    if not job.isRunning:
      debug fmt"Job {job.name} is not running; skipping"
      continue

    debug fmt"Bringing job DOWN: {job.name}"
    nomad.stopJob(job.name)

proc image(jobs, nomad) =
  for job in jobs:
    if not job.isRunning:
      debug fmt"Job {job.name} is not running; skipping"
      continue
    let
      live = nomad.liveImages(job.name).join("\n")
      spec = nomad.specImages(job).join("\n")

    if live.len == 0 and spec.len == 0:
      info fmt"Job {job.name} has no container images"
      continue

    var separator = ""
    if jobs.len > 1:
      echo &"Job: {job.name}\n"
      separator = "\n"

    echo &"Live images:\n{live}\n\nSpec images:\n{spec}{separator}"

proc logs(job: NomadJob, nomad) =
  let task = nomad.selectTask(job)
  nomad.tailLogs(taskName = task, jobName = job.name)

proc exec(job: NomadJob, nomad) =
  let task = nomad.selectTask(job)
  stdout.write fmt"Command to execute in {task}: "
  let subCmd = readLine(stdin)
  discard
    nomad.allocExec(taskName = task, jobName = job.name, subCmd = subCmd.parseCmdLine())

proc shell(job: NomadJob, nomad) =
  let task = nomad.selectTask(job)
  for shell in @["bash", "sh"]:
    debug fmt"Trying shell '{shell}' in {job.name}"
    # 126/127 = shell not found; return otherwise, i.e. on user exit from shell
    if nomad.allocExec(task, job.name, @[shell]) notin {126, 127}:
      return
  raise newException(NomadError, fmt"No shell found in {job.name} container")

proc reconcile(jobs, nomad) =
  for job in jobs:
    if not job.isRunning:
      debug fmt"Job {job.name} is not running; skipping"
      continue
    if job.isInfra:
      info fmt"Skipping infra job: {job.name}"
      continue
    if nomad.liveImages(job.name) == nomad.specImages(job):
      debug fmt"No changes for {job.name}; skipping"
      continue

    info fmt"Reconciling job {job.name}: image changed. Restarting..."
    nomad.runJob(job)

proc edit(job: NomadJob, nomad) =
  let
    spec = job.specPath
    editor = getEnv("EDITOR")

  if editor.len == 0:
    raise newException(NmgrError, "'$EDITOR environment variable not set")
  if editor.splitWhitespace().len > 1:
    raise newException(NmgrError, fmt"Invalid $EDITOR: {editor}")

  let cmd = parseCmdLine(editor) & $spec
  discard runProcess(cmd)

proc perform*(action: Action, jobs; nomad) =
  case action
  of acUp:
    up(jobs, nomad)
  of acDown:
    down(jobs, nomad)
  of acFind, acList:
    for job in jobs:
      echo job.name
  of acImage:
    image(jobs, nomad)
  of acReconcile:
    reconcile(jobs, nomad)
  of acLogs:
    logs(jobs[0], nomad)
  of acExec:
    exec(jobs[0], nomad)
  of acShell:
    shell(jobs[0], nomad)
  of acEdit:
    edit(jobs[0], nomad)
