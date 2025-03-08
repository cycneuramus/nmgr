import std/strformat
import ../action

type
  UpAction* = ref object of Action

method handle*(self: UpAction, target: string): void =
  echo(fmt"Starting job: {target}")

registerAction[UpAction](
  name = "up",
  desc = "Start job"
)

