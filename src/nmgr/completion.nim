import std/[dirs, files, os, paths, strformat, strutils]

proc genCompletion*() =
  const completionScript = staticRead("../../data/completion.bash")
  let
    dataDir = getEnv("XDG_DATA_HOME", getHomeDir() / ".local" / "share")
    scriptPath = Path(dataDir / "bash-completion" / "completions" / "nmgr")

  createDir(scriptPath.parentDir)

  var writeNeeded = true
  if fileExists(scriptPath):
    let cur = readFile($scriptPath).strip()
    if cur == completionScript.strip():
      echo fmt"Completion script is already up-to-date at {scriptPath}"
      writeNeeded = false
    else:
      echo fmt"Updating completion script at {scriptPath}"

  if not writeNeeded:
    return

  writeFile($scriptPath, completionScript)
  when defined(posix):
    setFilePermissions(
      $scriptPath,
      {
        fpUserRead, fpUserWrite, fpUserExec, fpGroupRead, fpGroupExec, fpOthersRead,
        fpOthersExec,
      },
    )

  echo fmt"Bash completion script installed at {scriptPath}"
