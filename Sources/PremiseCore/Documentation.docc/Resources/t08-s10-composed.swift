import PremiseCore
import PremiseStrategies

struct NetworkRequest: Sendable {
  var method: String
  var path: String
  var headers: [String: String]
  var body: [UInt8]?
}

let methodStrategy = Strategy<String>.oneOf([
  .just("GET"), .just("POST"), .just("PUT"), .just("DELETE"), .just("PATCH"),
])
let pathChars = Array("abcdefghijklmnopqrstuvwxyz0123456789-_")
let segmentStrategy = Strategy<String>.strings(from: pathChars, length: 1...12)
let pathStrategy = Strategy<[String]>.arrays(of: segmentStrategy, length: 1...5)
  .map { "/" + $0.joined(separator: "/") }
let headerKeyStrategy = Strategy<String>.strings(
  from: Array("abcdefghijklmnopqrstuvwxyz-"),
  length: 3...20
)
let headerValueStrategy = Strategy<String>.strings(from: pathChars, length: 1...50)

let requestStrategy = methodStrategy.flatMap { method in
  pathStrategy.flatMap { path in
    Strategy<[String: String]>.dictionaries(
      keys: headerKeyStrategy,
      values: headerValueStrategy,
      count: 0...5
    ).flatMap { headers in
      Strategy<[UInt8]>.bytes(length: 0...512).optional()
        .map { body in
          NetworkRequest(method: method, path: path, headers: headers, body: body)
        }
    }
  }
}
