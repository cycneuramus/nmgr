import std/[logging as stdlog, paths]

export stdlog except debug

proc debugLoc(info: tuple[filename: string, line: int, column: int], msg: string) =
  let
    fileName = $splitPath(Path(info.filename)).tail
    lineNum = $info.line
  stdlog.debug "[" & fileName & ":" & lineNum & "] " & msg

template debug*(msg: string) =
  debugLoc(instantiationInfo(-1), msg)
