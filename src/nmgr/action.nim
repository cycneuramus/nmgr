import std/[os, osproc, paths, strformat, strutils, with]
import ./[config, errors, jobs, logging, nomad, registry]

type
  NomadInterface* = enum
    niCli
    niApi

  Action* = object
    handler*: proc(jobs: seq[NomadJob], nomad: NomadClient, config: Config): void
    nomadInterface*: NomadInterface = niCli
    isSingleJob*: bool = false

using
  jobs: seq[NomadJob]
  nomad: NomadClient
  config: Config

proc selectTask(nomad; job: NomadJob): string =
  let tasks = nomad.getTasks(job.name)
  if tasks.len < 1:
    error fmt"No tasks found for job {job.name}"
    return
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

proc upHandler(jobs, nomad, config): void =
  for job in jobs:
    if job.isRunning:
      debug fmt"Job {job.name} is already running"

    debug fmt"Bringing job UP: {job.name}"
    nomad.runJob(job)

proc downHandler(jobs, nomad, config): void =
  for job in jobs:
    if not job.isRunning:
      debug fmt"Job {job.name} is not running; skipping"
      continue

    debug fmt"Bringing job DOWN: {job.name}"
    nomad.stopJob(job.name)

proc findHandler(jobs, nomad, config): void =
  for job in jobs:
    echo job.name

proc listHandler(jobs, nomad, config): void =
  for job in jobs:
    echo job.name

proc imageHandler(jobs, nomad, config): void =
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

proc logsHandler(jobs, nomad, config): void =
  let
    job = jobs[0]
    task = nomad.selectTask(job)
  if task.len < 1:
    return

  nomad.tailLogs(taskName = task, jobName = job.name)

proc execHandler(jobs, nomad, config): void =
  let
    job = jobs[0]
    task = nomad.selectTask(job)
  if task.len < 1:
    return

  echo fmt"Command to execute in {task}: "
  let subCmd = readLine(stdin)
  discard nomad.exec(taskName = task, jobName = job.name, subCmd = subCmd.split())

proc shellHandler(jobs, nomad, config): void =
  let
    job = jobs[0]
    task = nomad.selectTask(job)
  if task.len < 1:
    return

  for shell in @["bash", "sh"]:
    debug fmt"Trying shell '{shell}' in {job.name}"
    if nomad.exec(taskName = task, jobName = job.name, subCmd = @[shell]) == 0:
      return

  error fmt"No shell found in {job.name} container"

proc reconcileHandler(jobs, nomad, config): void =
  for job in jobs:
    if not job.isRunning:
      debug fmt"Job {job.name} is not running; skipping"
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
    if job.name in config.infraJobs:
      info fmt"Skipping infra job: {job.name}"
      continue

    info fmt"Reconciling job {job.name}: image changed. Restarting..."
    nomad.runJob(job)

proc editHandler(jobs, nomad, config): void =
  let
    job = jobs[0]
    spec = job.specPath

  let editor = getEnv("EDITOR")
  if editor.len == 0:
    error "'$EDITOR environment variable not set"
    return
  if editor.splitWhitespace().len > 1:
    error fmt"Invalid $EDITOR: {editor}"

  let process =
    startProcess(editor, args = [$spec], options = {poParentStreams, poUsePath})
  discard waitForExit(process)

func initActionRegistry*(): Registry[Action] =
  var registry = Action.initRegistry
  with registry:
    add("up", Action(handler: upHandler))
    add("down", Action(handler: downHandler, nomadInterface: niApi))
    add("find", Action(handler: findHandler))
    add("list", Action(handler: listHandler))
    add("image", Action(handler: imageHandler))
    add("logs", Action(handler: logsHandler, nomadInterface: niApi, isSingleJob: true))
    add("exec", Action(handler: execHandler, nomadInterface: niApi, isSingleJob: true))
    add(
      "shell", Action(handler: shellHandler, nomadInterface: niApi, isSingleJob: true)
    )
    add("reconcile", Action(handler: reconcileHandler))
    add("edit", Action(handler: editHandler, isSingleJob: true))
  return registry

proc handle*(
    action: Action, jobs: seq[NomadJob], nomad: NomadClient, config: Config
): void =
  let handle = action.handler
  try:
    jobs.handle(nomad, config)
  except CatchableError as e:
    raise newException(ActionError, fmt"{e.msg}")
