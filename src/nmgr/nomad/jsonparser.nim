import std/[json, strformat, strutils]
import ../[errors, logging]

proc parseResponse*(body: string): JsonNode =
  debug fmt"Parsing JSON response"
  try:
    result = parseJson(body)
  except JsonParsingError as e:
    raise newException(NomadError, fmt"Failed to parse JSON response: {e.msg}")

func parseImages*(json: JsonNode): seq[string] =
  if not json.hasKey("TaskGroups"):
    return
  for taskGroup in json["TaskGroups"].items:
    if taskGroup.kind != JObject or not taskGroup.hasKey("Tasks"):
      continue
    for task in taskGroup["Tasks"].items:
      if task.kind != JObject:
        continue
      if not task.hasKey("Config"):
        continue

      let config = task["Config"]
      proc checkImage(node: JsonNode): seq[string] =
        if node.kind == JObject:
          if node.hasKey("image"):
            let image = node["image"].getStr("")
            if image.len > 0 and not image.contains("local."):
              result.add(image)
          for _, value in node:
            result = result & checkImage(value)
        elif node.kind == JArray:
          for item in node.items:
            result = result & checkImage(item)

      result = result & checkImage(config)

func parseTasks*(json: JsonNode): seq[string] =
  if not json.hasKey("TaskGroups"):
    return
  for taskGroup in json["TaskGroups"].items:
    if taskGroup.kind != JObject or not taskGroup.hasKey("Tasks"):
      continue
    for task in taskGroup["Tasks"].items:
      if task.hasKey("Name"):
        result.add task["Name"].getStr("")

func parseAllocId*(json: JsonNode): string =
  if json.kind != JArray:
    return
  for alloc in json:
    if alloc.kind != JObject:
      continue
    let status = alloc.getOrDefault("ClientStatus").getStr("")
    if status == "running":
      return alloc.getOrDefault("ID").getStr("")

func parseJobs*(json: JsonNode): seq[string] =
  if json.kind != JArray:
    return
  for job in json:
    if job.kind != JObject:
      continue
    if not job.hasKey("Status"):
      continue
    let status = job["Status"].getStr.toLowerAscii
    if status == "running":
      if not job.hasKey("Name"):
        continue
      let name = job["Name"].getStr
      if name.len > 0:
        result.add(name)
