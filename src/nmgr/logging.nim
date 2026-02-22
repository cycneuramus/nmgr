import std/[logging as stdlog, paths]

export stdlog.Level
export stdlog.addHandler
export stdlog.newConsoleLogger
export stdlog.newFileLogger
export stdlog.Logger

export stdlog.warn
export stdlog.info
export stdlog.error
export stdlog.fatal

proc debugLoc(info: tuple[filename: string, line: int, column: int], msg: string) =
  let fileName = $splitPath(Path(info.filename)).tail
  let lineNum = $info.line
  stdlog.debug "[" & fileName & ":" & lineNum & "] " & msg

template debug*(msg: string) =
  debugLoc(instantiationInfo(-1), msg)
