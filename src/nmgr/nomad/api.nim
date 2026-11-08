import std/[httpclient, strformat, strutils, uri]
import ../[errors, logging]

type
  Transport* = proc(verb: HttpMethod, url: string): string
  NomadApi* = object
    server*: string
    send*: Transport

using self: NomadApi

proc httpTransport*(): Transport =
  let client = newHttpClient(timeout = 5000)
  client.headers["Content-Type"] = "application/json"
  result = proc(verb: HttpMethod, url: string): string =
    let response = client.request(url, httpMethod = verb)
    debug fmt"Response status: {response.status}"
    if not response.code.is2xx:
      raise newException(
        NomadError, fmt"{verb} {url} failed: {response.status} {response.body}"
      )
    response.body

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

proc get*(self; path: string, query: seq[(string, string)] = @[]): string =
  return self.send(HttpGet, buildUrl(self.server, path, query))

proc delete*(self; path: string, query: seq[(string, string)] = @[]): string =
  return self.send(HttpDelete, buildUrl(self.server, path, query))
