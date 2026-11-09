import std/[logging as stdlog, paths]

export stdlog except debug

proc debugAt(loc: tuple[filename: string, line: int, column: int], msg: string) =
  let fileName = Path(loc.filename).extractFilename()
  stdlog.debug "[" & $fileName & ":" & $loc.line & "] " & msg

template debug*(msg: string) =
  debugAt(instantiationInfo(-1), msg)
