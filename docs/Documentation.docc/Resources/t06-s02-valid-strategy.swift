import PremiseStrategies
import PremiseTesting
import Testing

/// Characters that are always valid in the interior of a username.
let interior = Array("abcdefghijklmnopqrstuvwxyz0123456789")
/// Characters valid in the interior plus underscore (but not at edges).
let interiorWithUnderscore = interior + ["_"]
/// Characters valid at edges (no underscore).
let edge = interior

func removeConsecutiveUnderscores(_ characters: [Character]) -> [Character] {
  var cleaned: [Character] = []
  for character in characters {
    if character == "_", cleaned.last == "_" {
      continue
    }
    cleaned.append(character)
  }
  return cleaned
}

/// Strategy for valid usernames: starts and ends with [a-z0-9],
/// has 1-18 interior characters from [a-z0-9_], and never has "__".
let validUsernameStrategy: Strategy<String> = Strategy<Character>
  .oneOf(edge.map { .just($0) })
  .flatMap { firstChar in
    // Interior: 1-18 characters, no consecutive underscores
    Strategy<[Character]>.arrays(
      of: .oneOf(interiorWithUnderscore.map { .just($0) }),
      length: 1...18
    )
    .map { middle in
      removeConsecutiveUnderscores(middle)
    }
    .flatMap { middle in
      Strategy<Character>.oneOf(edge.map { .just($0) })
        .map { lastChar in
          String([firstChar] + middle + [lastChar])
        }
    }
  }
