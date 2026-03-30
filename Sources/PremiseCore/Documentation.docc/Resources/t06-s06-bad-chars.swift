import Testing
import PremiseTesting
import PremiseStrategies

let validator = UsernameValidator()
let safe = Array("abcdefghijklmnopqrstuvwxyz")
let invalid = Array("!@#$%^&*()+=[]{}|;:',.<>?/ ")

// Strategy: a safe base with one invalid character injected somewhere.
let badCharStrategy = Strategy<String>
  .strings(from: safe, length: 2...18)
  .flatMap { base in
    Strategy<Character>.oneOf(invalid.map { .just($0) })
      .flatMap { badChar in
        Strategy<Int>.integers(in: 0...base.count)
          .map { position in
            var chars = Array(base)
            chars.insert(badChar, at: position)
            return String(chars)
          }
      }
  }

@Test func invalidCharacterAlwaysFails() async throws {
  try await forAll(badCharStrategy) { username in
    #expect(throws: UsernameValidator.ValidationError.invalidCharacter) {
      try validator.validate(username)
    }
  }
}
