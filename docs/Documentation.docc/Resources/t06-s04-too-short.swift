import Testing
import PremiseTesting
import PremiseStrategies

let validator = UsernameValidator()
let safe = Array("abcdefghijklmnopqrstuvwxyz")

// Usernames shorter than 3 characters — always invalid.
let tooShortStrategy = Strategy<String>.strings(from: safe, length: 0...2)

@Test
func tooShortUsernameAlwaysFails() async throws {
  try await forAll(tooShortStrategy) { username in
    #expect(throws: UsernameValidator.ValidationError.tooShort) {
      try validator.validate(username)
    }
  }
}
