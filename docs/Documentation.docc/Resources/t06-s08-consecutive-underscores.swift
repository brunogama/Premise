import Testing
import PremiseTesting
import PremiseStrategies

let validator = UsernameValidator()
let safe = Array("abcdefghijklmnopqrstuvwxyz")

// Usernames with consecutive underscores injected into an otherwise valid base.
let doubleUnderscoreStrategy = Strategy<String>
  .strings(from: safe, length: 2...16)
  .map { base in "a" + base + "__" + "z" }  // always has "__", valid edge chars

@Test func consecutiveUnderscoresAlwaysFail() async throws {
  try await forAll(doubleUnderscoreStrategy) { username in
    #expect(throws: UsernameValidator.ValidationError.consecutiveUnderscores) {
      try validator.validate(username)
    }
  }
}
