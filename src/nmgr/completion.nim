import std/[appdirs, dirs, files, paths, strformat, strutils]

proc genCompletion*() =
  const completionScript = staticRead("../../data/completion.bash")
  let scriptPath = getDataDir() / Path("bash-completion/completions/nmgr")

  createDir(scriptPath.parentDir)

  if fileExists(scriptPath) and readFile($scriptPath).strip() == completionScript.strip():
    echo fmt"Completion script is already up-to-date at {scriptPath}"
    return

  writeFile($scriptPath, completionScript)
  echo fmt"Bash completion script installed at {scriptPath}"
