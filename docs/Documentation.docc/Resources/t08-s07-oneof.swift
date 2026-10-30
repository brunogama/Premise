import Testing
import PremiseTesting
import PremiseStrategies

// Mix well-known status codes with a wider generated range.
let httpStatusStrategy = Strategy<Int>.oneOf([
  .just(200), .just(201), .just(204),
  .just(400), .just(401), .just(403), .just(404),
  .just(500), .just(502), .just(503),
  .integers(in: 100...599),  // catch-all for any valid code
])

@Test func httpStatusIsInValidRange() async throws {
  try await forAll(httpStatusStrategy) { status in
    #expect((100...599).contains(status))
  }
}
