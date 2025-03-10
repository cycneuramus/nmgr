import tables, strformat

# Defines a generic type parameterized on 'T' (e.g. Action or Target)
type
  # The table associates string keys with values of type T
  Registry*[T] = Table[string, T]

proc newRegistry*[T](): Registry[T] =
  initTable[string, T]()

# 'var Registry[T]' indicates that 'registry' will be modified in-place
proc add*[T](registry: var Registry[T], key: string, value: T) =
  if key in registry:
    raise newException(ValueError, fmt"'{key}' is already registered")
  registry[key] = value

proc get*[T](registry: Registry[T], key: string): T =
  if key in registry:
    return registry[key]
  raise newException(ValueError, fmt"Unknown key '{key}'")
