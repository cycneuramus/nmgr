import options, sequtils, strutils

## Represents a key-value pair inside a block
type HclAttr* = object
  key*: string
  value*: string

## Represents a named or unnamed block (e.g. `job "name" { ... }`)
## Since this is a tree, we want a ref so as not to store full copies
type HclBlock* = ref object
  blockType*: string # e.g. "job", "task", "locals"
  name*: Option[string] # Some("name") if named like `job "name"`
  attrs*: seq[HclAttr] # List of key-value pairs
  children*: seq[HclBlock] # Nested blocks

## Represents a full parsed HCL document
type HclDocument* = object
  rootBlocks*: seq[HclBlock] # Top-level blocks (usually `locals`, `job`, etc.)

# === Utilities ===

func stripComments(s: string): string =
  for commentStart in ["#", "//"]:
    let idx = s.find(commentStart)
    if idx != -1:
      return s[0 ..< idx].strip()
  result = s.strip()

func isBlockHeader(line: string): bool =
  let l = line.strip()
  if l.len == 0 or l.startsWith("#") or l.startsWith("//"):
    return false
  # Assignments make it a key-value pair, not a block
  if "=" in l:
    return false
  return l.contains("{")

func extractBlockParts(line: string): (string, Option[string]) =
  # Example: `job "transfer"` -> ("job", Some("transfer"))
  let parts = line.splitWhitespace()
  if parts.len == 1:
    (parts[0], none(string))
  elif parts.len > 1 and parts[1].startsWith('"'):
    (parts[0], some(parts[1].strip(chars = {'"'})))
  else:
    (parts[0], none(string))

# === Core ===

func parseBlock(lines: seq[string], idx: var int): HclBlock =
  # Create the block with type and optional name
  let (blockType, blockName) = extractBlockParts(stripComments(lines[idx]))
  let hclBlock = HclBlock(blockType: blockType, name: blockName)

  inc(idx) # Advance past the opening line
  var braceDepth = 1 # Track how deeply nested we are

  while idx < lines.len and braceDepth > 0:
    var line = stripComments(lines[idx])

    if line.len == 0:
      inc(idx)
      continue

    # Key-value pair (attribute)
    if "=" in line:
      let parts = line.split('=', 1)
      let key = parts[0].strip()
      var value = parts[1].strip()

      # Handle inline map (e.g. `image = { key = "..." }`)
      if value == "{" or value.endsWith("{"):
        var mapBlock: string
        var mapDepth = 1
        inc(idx)

        while idx < lines.len and mapDepth > 0:
          let l = stripComments(lines[idx])
          mapDepth += l.count('{')
          mapDepth -= l.count('}')
          mapBlock.add(l & "\n")
          inc(idx)

        # Store as a single string value including the braces
        hclBlock.attrs.add(HclAttr(key: key, value: "{" & mapBlock.strip() & "}"))
        continue
      else:
        # Store simple key-value
        hclBlock.attrs.add(HclAttr(key: key, value: value))
        inc(idx)
        continue

    # End of block
    elif line == "}":
      braceDepth.dec()

    # Start of nested block
    elif isBlockHeader(line):
      hclBlock.children.add(parseBlock(lines, idx))
      continue

    # Possible multi-line block continuation
    elif line.endsWith("{"):
      braceDepth.inc()

    inc(idx)

  return hclBlock

func parseHcl*(spec: string): HclDocument =
  var doc = HclDocument()
  let lines = spec.splitLines()
  var idx: int

  while idx < lines.len:
    let line = stripComments(lines[idx])
    if isBlockHeader(line):
      doc.rootBlocks.add(parseBlock(lines, idx))
    else:
      inc(idx)

  return doc

# === Low-level query helpers ===

# Get all top-level blocks of a given type (e.g. "job", "locals")
func getBlocksOfType*(doc: HclDocument, blockType: string): seq[HclBlock] =
  result = doc.rootBlocks.filterIt(it.blockType == blockType)

# Get a specific key's value from a block (e.g. "image")
func getAttr*(hclBlock: HclBlock, key: string): Option[string] =
  for attr in hclBlock.attrs:
    if attr.key == key:
      return some(attr.value)
  return none(string)

# Find a block by name from a list of blocks
func findBlockByName*(blocks: seq[HclBlock], name: string): Option[HclBlock] =
  for b in blocks:
    if b.name.isSome and b.name.get == name:
      return some(b)
  return none(HclBlock)

# === High-level query helpers ===

# Extract the job name (first "job" block found)
func getJobName*(doc: HclDocument): Option[string] =
  for hclBlock in doc.rootBlocks:
    if hclBlock.blockType == "job":
      return hclBlock.name
  return none(string)

# Recursively find all task names under a given block
func getTasks*(hclBlock: HclBlock): seq[string] =
  if hclBlock.blockType == "task" and hclBlock.name.isSome:
    result.add(hclBlock.name.get)

  for child in hclBlock.children:
    result.add(child.getTasks())

# Extract container image values from the `locals` block
func extractImages*(doc: HclDocument): seq[string] =
  for hclBlock in doc.rootBlocks:
    if hclBlock.blockType != "locals" and hclBlock.blockType != "config":
      continue

    for attr in hclBlock.attrs:
      if attr.key == "image":
        let value = attr.value.strip()

        # If it's a map, extract the values line-by-line
        if value.startsWith('{') and value.endsWith('}'):
          let content = value[1 ..< value.len - 1]
          for line in content.splitLines:
            let l = line.strip()
            if '=' notin l:
              continue

            let parts = l.split('=', 1)
            if parts.len != 2:
              continue
            let img = parts[1].strip(chars = {'"', ' '})
            if not img.contains("local."):
              result.add(img)
        else:
          # It's a single string value
          let single = value.strip(chars = {'"'})
          if not single.contains("local."): # skip HCL variable references
            result.add(single)
