import std/[httpclient, strformat, strutils, uri]
import ../[errors, logging]

type NomadApi* = object
  server*: string
  caller*: proc(httpMethod: string, endpoint: string): string
  http*: HttpClient

using self: NomadApi

proc newHttp*(): HttpClient =
  var client = newHttpClient(timeout = 5000)
  client.headers.add("Content-Type", "application/json")
  return client

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
    self; verb: HttpMethod, path: string, query: seq[(string, string)] = @[]
): string =
  let endpoint = buildUrl(self.server, path, query)
  if not self.caller.isNil:
    return self.caller($verb, endpoint)

  let response = self.http.request(endpoint, httpMethod = verb)
  debug fmt"Response status: {response.status}"
  if not response.code.is2xx:
    raise newException(
      NomadError, fmt"{verb} {endpoint} failed: {response.status} {response.body}"
    )

proc get*(self; path: string, query: seq[(string, string)] = @[]): string =
  return self.call(HttpGet, path, query)

proc delete*(self; path: string, query: seq[(string, string)] = @[]): string =
  return self.call(HttpDelete, path, query)
