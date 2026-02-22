## Provides a registry that takes a string key and a generic value

import std/[strformat, tables]

type Registry*[T] = OrderedTable[string, T]

func initRegistry*[T](t: typedesc[T]): Registry[T] =
  ## Initializes a new registry for type T. The unused 'typedesc' parameter
  ## is purely for the benefit of the compiler and lets one do something like
  ## 'Cat.initRegistry' instead of, say, initRegistry[Cat]().
  initOrderedTable[string, T]()

func add*[T](registry: var Registry[T], key: string, value: T) =
  ## Adds an entry to the registry
  if key in registry:
    raise newException(KeyError, fmt"'{key}' is already registered")
  registry[key] = value

func get*[T](registry: Registry[T], key: string): T =
  ## Gets an entry from the registry by key
  if key in registry:
    return registry[key]
  raise newException(KeyError, fmt"Unknown key '{key}'")
