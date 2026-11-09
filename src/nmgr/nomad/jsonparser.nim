import std/[json, sequtils, strformat]
import ../[errors, logging]

proc parseNomadJson*(body: string): JsonNode =
  debug fmt"Parsing JSON response"
  try:
    parseJson(body)
  except JsonParsingError as e:
    raise newException(NomadError, fmt"Failed to parse JSON response: {e.msg}")

iterator tasks(job: JsonNode): JsonNode =
  for group in job{"TaskGroups"}.getElems():
    for task in group{"Tasks"}.getElems():
      yield task

func collectImages(node: JsonNode, images: var seq[string]) =
  if node.isNil:
    return
  case node.kind
  of JObject:
    let image = node{"image"}.getStr
    if image.len > 0:
      images.add(image)
    for _, value in node:
      collectImages(value, images)
  of JArray:
    for item in node:
      collectImages(item, images)
  else:
    discard

func images*(job: JsonNode): seq[string] =
  for task in job.tasks:
    collectImages(task{"Config"}, result)
  result.deduplicate()

func taskNames*(job: JsonNode): seq[string] =
  for task in job.tasks:
    let name = task{"Name"}.getStr()
    if name.len > 0:
      result.add(name)

func runningAllocId*(allocs: JsonNode): string =
  for alloc in allocs.getElems():
    if alloc{"ClientStatus"}.getStr() == "running":
      return alloc{"ID"}.getStr()

func runningJobNames*(jobs: JsonNode): seq[string] =
  for job in jobs.getElems():
    let name = job{"Name"}.getStr()
    if name.len > 0 and job{"Status"}.getStr() == "running":
      result.add(name)
