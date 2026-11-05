import Testing
import PremiseTesting
import PremiseStrategies

let validator = UsernameValidator()
let safe = Array("abcdefghijklmnopqrstuvwxyz")

let tooShortStrategy = Strategy<String>.strings(from: safe, length: 0...2)
let tooLongStrategy = Strategy<String>.strings(from: safe, length: 21...50)

@Test func tooShortUsernameAlwaysFails() async throws {
  try await forAll(tooShortStrategy) { username in
    #expect(throws: UsernameValidator.ValidationError.tooShort) {
      try validator.validate(username)
    }
  }
}

@Test func tooLongUsernameAlwaysFails() async throws {
  try await forAll(tooLongStrategy) { username in
    #expect(throws: UsernameValidator.ValidationError.tooLong) {
      try validator.validate(username)
    }
  }
}
