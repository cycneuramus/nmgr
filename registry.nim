## Provides a registry type that takes a string key and a generic value

import std/[tables, strformat]

type
  Registry*[T] = Table[string, T]

proc newRegistry*[T](): Registry[T] =
  ## Initializes a new registry
  initTable[string, T]()

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
  type
    Cat = object
      name: string
      age: int

  let kitten = Cat(name: "Simba", age: 1)
  let cat = Cat(name: "Mufasa", age: 5)

  var catRegistry = newRegistry[Cat]()

  registry.add(
    catRegistry,
    kitten.name,
    kitten
  )

  registry.add(
    catRegistry,
    cat.name,
    cat
  )

  assert registry.get(catRegistry, "Simba") == kitten
  assert registry.get(catRegistry, "Mufasa") == cat
