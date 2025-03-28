import std/[logging, paths, strformat, strutils, tables, with]
import ./[config, jobs, nomad, registry]

type
  ActionHandler = proc(jobs: seq[NomadJob], nomad: NomadClient, config: Config): void
  UnknownActionError = object of CatchableError

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
    stdout.write "Select a task (number): "
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
    if nomad.isRunning(job.name):
      debug fmt"Job {job.name} is already running"

    debug fmt"Bringing job UP: {job.name}"
    nomad.runJob(job)

proc downHandler(jobs, nomad, config): void =
  for job in jobs:
    if not nomad.isRunning(job.name):
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
    let live = nomad.getLiveImage(job.name)
    let spec = nomad.getSpecImage(readSpec($job.specPath))
    echo &"Live images:\n{live}\n\nSpec images:\n{spec}"

proc logsHandler(jobs, nomad, config): void =
  if jobs.len > 1:
    error "Logs cannot be shown for more than one job at a time"
    return

  let job = jobs[0]
  let task = nomad.selectTask(job)
  if task.len < 1:
    return
  nomad.tailLogs(taskName = task, jobName = job.name)

proc execHandler(jobs, nomad, config): void =
  if jobs.len > 1:
    error "Exec cannot be run for more than one job at a time"
    return

  let job = jobs[0]
  let task = nomad.selectTask(job)
  if task.len < 1:
    return

  echo fmt"Command to execute in {task}: "
  let subCmd = readLine(stdin)
  nomad.exec(taskName = task, jobName = job.name, subCmd = subCmd.split())

proc reconcileHandler(jobs, nomad, config): void =
  for job in jobs:
    if not nomad.isRunning(job.name):
      debug fmt"Job {job.name} is not running; skipping"
      continue

    let liveImage = nomad.getLiveImage(job.name)
    let specImage = nomad.getSpecImage(readSpec($job.specPath))

    if liveImage == specImage:
      debug fmt"No changes for {job.name}; skipping"
      continue
    if job.name in config.infraJobs:
      info fmt"Skipping infra job: {job.name}"
      continue

    info fmt"Reconciling job {job.name}: image changed. Restarting..."
    nomad.runJob(job)

func initActionRegistry*(): Registry[ActionHandler] =
  var registry = ActionHandler.initRegistry
  with registry:
    add("up", upHandler)
    add("down", downHandler)
    add("find", findHandler)
    add("list", listHandler)
    add("image", imageHandler)
    add("logs", logsHandler)
    add("exec", execHandler)
    add("reconcile", reconcileHandler)
  return registry

proc handle*(
    action: string,
    registry: Registry[ActionHandler],
    jobs: seq[NomadJob],
    nomad: NomadClient,
    config: Config,
): void =
  let handle =
    if registry.hasKey(action):
      registry[action]
    else:
      raise newException(UnknownActionError, fmt"'{action}' is unknown")

  jobs.handle(nomad, config)
