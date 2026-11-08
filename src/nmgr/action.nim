import std/[os, osproc, paths, strformat, strutils]
import ./[config, errors, jobs, logging, nomad]

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
  let tasks = nomad.getTasks(job.name)
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
      else:
        echo "Invalid choice. Please enter a valid number."
    except CatchableError:
      echo "Please enter a valid number."

proc up(jobs, nomad): void =
  for job in jobs:
    if job.isRunning:
      debug fmt"Job {job.name} is already running"
      continue

    debug fmt"Bringing job UP: {job.name}"
    nomad.runJob(job)

proc down(jobs, nomad): void =
  for job in jobs:
    if not job.isRunning:
      debug fmt"Job {job.name} is not running; skipping"
      continue

    debug fmt"Bringing job DOWN: {job.name}"
    nomad.stopJob(job.name)

proc image(jobs, nomad): void =
  for job in jobs:
    let live =
      try:
        nomad.getLiveImage(job.name).join("\n")
      except NomadError as e:
        debug e.msg
        continue
    let spec =
      try:
        nomad.getSpecImage(job.specPath).join("\n")
      except NomadError as e:
        debug e.msg
        continue

    var separator = ""
    if jobs.len > 1:
      echo &"Job: {job.name}\n"
      separator = "\n"

    echo &"Live images:\n{live}\n\nSpec images:\n{spec}{separator}"

proc logs(job: NomadJob, nomad): void =
  let task = nomad.selectTask(job)
  nomad.tailLogs(taskName = task, jobName = job.name)

proc exec(job: NomadJob, nomad): void =
  let task = nomad.selectTask(job)
  stdout.write fmt"Command to execute in {task}: "
  let subCmd = readLine(stdin)
  discard
    nomad.exec(taskName = task, jobName = job.name, subCmd = subCmd.parseCmdLine())

proc shell(job: NomadJob, nomad): void =
  let task = nomad.selectTask(job)
  for shell in @["bash", "sh"]:
    debug fmt"Trying shell '{shell}' in {job.name}"
    if nomad.exec(taskName = task, jobName = job.name, subCmd = @[shell]) == 0:
      return

  error fmt"No shell found in {job.name} container"

proc reconcile(jobs, nomad): void =
  for job in jobs:
    if not job.isRunning:
      debug fmt"Job {job.name} is not running; skipping"
      continue

    if job.name in nomad.config.infraJobs:
      info fmt"Skipping infra job: {job.name}"
      continue

    let liveImage =
      try:
        nomad.getLiveImage(job.name)
      except NomadError as e:
        debug e.msg
        continue
    let specImage =
      try:
        nomad.getSpecImage(job.specPath)
      except NomadError as e:
        debug e.msg
        continue

    if liveImage == specImage:
      debug fmt"No changes for {job.name}; skipping"
      continue

    info fmt"Reconciling job {job.name}: image changed. Restarting..."
    nomad.runJob(job)

proc edit(job: NomadJob, nomad): void =
  let
    spec = job.specPath
    editor = getEnv("EDITOR")

  if editor.len == 0:
    error "'$EDITOR environment variable not set"
    return
  if editor.splitWhitespace().len > 1:
    error fmt"Invalid $EDITOR: {editor}"
    return

  let process =
    startProcess(editor, args = [$spec], options = {poParentStreams, poUsePath})
  defer:
    process.close()
  discard waitForExit(process)

proc perform*(action: Action, jobs; nomad): void =
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
