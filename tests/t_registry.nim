import std/[sequtils, tables, unittest]
import ../src/nmgr/registry

type Cat = object
  age: int

func makeCat(age: int): Cat =
  Cat(age: age)

suite "Registry":
  test "initRegistry creates empty registry":
    let registry = Cat.initRegistry
    check registry.len == 0

  test "add stores entry in registry":
    var registry = Cat.initRegistry
    let cat = makeCat(5)
    registry.add("Simba", cat)

    check:
      registry.len == 1
      "Simba" in registry

  test "add raises KeyError on duplicate key":
    var registry = Cat.initRegistry
    registry.add("Simba", makeCat(5))

    expect KeyError:
      registry.add("Simba", makeCat(3))

  test "get retrieves entry by key":
    var registry = Cat.initRegistry
    let cat = makeCat(5)
    registry.add("Simba", cat)

    let result = registry.get("Simba")

    check:
      result == cat
      result.age == 5

  test "get raises KeyError for unknown key":
    let registry = Cat.initRegistry

    expect KeyError:
      discard registry.get("Unknown")

  test "get returns correct entry for multiple items":
    var registry = Cat.initRegistry
    let kitten = makeCat(1)
    let cat = makeCat(5)
    registry.add("Simba", kitten)
    registry.add("Mufasa", cat)

    check:
      registry.get("Simba") == kitten
      registry.get("Mufasa") == cat
      registry.len == 2

  test "registry preserves insertion order":
    var registry = Cat.initRegistry
    registry.add("first", makeCat(1))
    registry.add("second", makeCat(2))
    registry.add("third", makeCat(3))

    let keys = toSeq(registry.keys)

    check:
      keys.len == 3
      keys[0] == "first"
      keys[1] == "second"
      keys[2] == "third"
