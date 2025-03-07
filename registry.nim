import tables

# Defines a generic type parameterized on 'T' (e.g. ActionHandler or TargetHandler)
type
  # The table associates string keys with values of type T
  Registry*[T] = Table[string, T]

# Instantiates a Registry
proc newRegistry*[T](): Registry[T] =
  initTable[string, T]()

# Adds a new key-value pair to the registry
# 'var Registry[T]' indicates that 'registry' will be modified in-place
proc add*[T](registry: var Registry[T], name: string, value: T) =
  if name in registry:
    raise newException(ValueError, fmt"'{name}' is already registered")
  registry[name] = value

# Gets a value from the registry by key
proc get*[T](registry: Registry[T], name: string): T =
  if name notin registry:
    raise newException(ValueError, fmt"Unknown key '{name}'")
  return registry[name]
