import std/[httpclient, strformat, strutils, uri]
import ./http

type NomadApi* = object
  server*: string
  caller*: proc(httpMethod: string, endpoint: string): string

using self: NomadApi

func buildUrl(
    server: string, path: string, query: seq[(string, string)] = @[]
): string =
  var uri = parseUri(server)
  uri.path =
    if path.startsWith("/"):
      path
    else:
      "/" & path
  if query.len > 0:
    uri.query = encodeQuery(query)
  return $uri

proc call*(
    self; httpMethod: string, path: string, query: seq[(string, string)] = @[]
): string =
  let endpoint = buildUrl(self.server, path, query)
  if self.caller.isNil:
    case httpMethod.toUpperAscii
    of "GET":
      result = httpGet(endpoint).body
    of "DELETE":
      result = httpDelete(endpoint).body
    else:
      raise newException(ValueError, fmt"Unsupported HTTP method: {httpMethod}")
  else:
    result = self.caller(httpMethod, endpoint)

proc get*(self; path: string, query: seq[(string, string)] = @[]): string =
  return self.call("GET", path, query)

proc delete*(self; path: string, query: seq[(string, string)] = @[]): string =
  return self.call("DELETE", path, query)
