import Testing
import PremiseTesting
import PremiseStrategies

// Characters that are always valid in the interior of a username.
let interior = Array("abcdefghijklmnopqrstuvwxyz0123456789")
// Characters valid in the interior plus underscore (but not at edges).
let interiorWithUnderscore = interior + ["_"]
// Characters valid at edges (no underscore).
let edge = interior

// Strategy for valid usernames: starts and ends with [a-z0-9],
// has 1-18 interior characters from [a-z0-9_], and never has "__".
let validUsernameStrategy: Strategy<String> = Strategy<Character>
  .oneOf(edge.map { .just($0) })
  .flatMap { firstChar in
    // Interior: 1-18 characters, no consecutive underscores
    Strategy<[Character]>.arrays(
      of: .oneOf(interiorWithUnderscore.map { .just($0) }),
      length: 1...18
    )
    .map { middle in
      // Remove consecutive underscores from the middle
      var cleaned: [Character] = []
      for c in middle {
        if c == "_" && cleaned.last == "_" { continue }
        cleaned.append(c)
      }
      return cleaned
    }
    .flatMap { middle in
      Strategy<Character>.oneOf(edge.map { .just($0) })
        .map { lastChar in
          String([firstChar] + middle + [lastChar])
        }
    }
  }
