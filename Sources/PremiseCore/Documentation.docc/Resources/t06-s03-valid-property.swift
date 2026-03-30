import Testing
import PremiseTesting
import PremiseStrategies

let validator = UsernameValidator()
// (validUsernameStrategy defined in previous step)

@Test func validUsernameAlwaysPasses() async throws {
  try await forAll(validUsernameStrategy) { username in
    // Every value from this strategy satisfies all validator rules.
    // If the validator rejects it, we have a bug in the validator.
    #expect(throws: Never.self) {
      try validator.validate(username)
    }
  }
}
