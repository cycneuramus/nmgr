import std/[httpclient, strformat, strutils, uri]
import ../logging

type NomadApi* = object
  server*: string
  caller*: proc(httpMethod: string, endpoint: string): string
  http*: HttpClient

using self: NomadApi

proc newHttp*(): HttpClient =
  var client = newHttpClient()
  client.headers.add("Content-Type", "application/json")
  return client

proc httpGet*(self; endpoint: string): Response =
  debug fmt"GET {endpoint}"

  let response = self.http.request(endpoint, httpMethod = HttpGet)
  debug fmt"Response status: {response.status}"
  return response

proc httpDelete*(self; endpoint: string): Response =
  debug fmt"DELETE {endpoint}"

  let response = self.http.request(endpoint, httpMethod = HttpDelete)
  debug fmt"Response status: {response.status}"
  return response

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
      result = self.httpGet(endpoint).body
    of "DELETE":
      result = self.httpDelete(endpoint).body
    else:
      raise newException(ValueError, fmt"Unsupported HTTP method: {httpMethod}")
  else:
    result = self.caller(httpMethod, endpoint)

proc get*(self; path: string, query: seq[(string, string)] = @[]): string =
  return self.call("GET", path, query)

proc delete*(self; path: string, query: seq[(string, string)] = @[]): string =
  return self.call("DELETE", path, query)
