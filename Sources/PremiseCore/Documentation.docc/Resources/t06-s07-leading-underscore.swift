import Testing
import PremiseTesting
import PremiseStrategies

let validator = UsernameValidator()
let safe = Array("abcdefghijklmnopqrstuvwxyz0123456789")

// Usernames that start with underscore — leading underscore rule.
let leadingUnderscoreStrategy = Strategy<String>
  .strings(from: safe, length: 2...19)
  .map { "_" + $0 }  // prepend underscore: always invalid, always right length

@Test func leadingUnderscoreAlwaysFails() async throws {
  try await forAll(leadingUnderscoreStrategy) { username in
    #expect(throws: UsernameValidator.ValidationError.leadingUnderscore) {
      try validator.validate(username)
    }
  }
}
