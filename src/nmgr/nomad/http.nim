import std/[httpclient, logging, strformat]

# TODO: don't recreate HTTP client in procs
proc newHttp*(): HttpClient =
  var client = newHttpClient()
  client.headers.add("Content-Type", "application/json")
  return client

proc httpGet*(endpoint: string): Response =
  let httpClient = newHttp()
  debug fmt"GET {endpoint}"

  let response = httpClient.request(endpoint, httpMethod = HttpGet)
  debug fmt"Response status: {response.status}"
  return response

proc httpDelete*(endpoint: string): Response =
  let httpClient = newHttp()
  debug fmt"DELETE {endpoint}"

  let response = httpClient.request(endpoint, httpMethod = HttpDelete)
  debug fmt"Response status: {response.status}"
  return response
