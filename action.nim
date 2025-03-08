type
  Action* = ref object of RootObj
    name*: string
    desc*: string

method handle*(self: Action, target: string) {.base.} = discard

var actions*: seq[Action] = @[]

# Need to use generics to specify subtype since otherwise Nim will
# register the base Action, which only has the abstract method
proc registerAction*[T: Action](name, desc: string): void =
  actions.add T(
    name: name,
    desc: desc,
  )

proc findAction*(name: string): Action =
  for action in actions:
    if action.name == name:
      return action
