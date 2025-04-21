## Provides a registry that takes a string key and a generic value

import std/[strformat, tables]

type Registry*[T] = OrderedTable[string, T]

proc initRegistry*[T](t: typedesc[T]): Registry[T] =
  ## Initializes a new registry for type T
  initOrderedTable[string, T]()

proc add*[T](registry: var Registry[T], key: string, value: T) =
  ## Adds an entry to the registry
  if key in registry:
    raise newException(ValueError, fmt"'{key}' is already registered")
  registry[key] = value

proc get*[T](registry: Registry[T], key: string): T =
  ## Gets an entry from the registry by key
  if key in registry:
    return registry[key]
  raise newException(ValueError, fmt"Unknown key '{key}'")

runnableExamples:
  type Cat = object
    name: string
    age: int

  let kitten = Cat(name: "Simba", age: 1)
  let cat = Cat(name: "Mufasa", age: 5)

  var catRegistry = Cat.initRegistry
  catRegistry.add(kitten.name, kitten)
  catRegistry.add(cat.name, cat)

  assert catRegistry.get("Simba") == kitten
  assert catRegistry.get("Mufasa") == cat
