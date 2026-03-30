import Testing
import PremiseTesting
import PremiseStrategies

// Assumes: jsonStrategy, JSON type, prettyPrint(_:), parseJSON(_:) defined elsewhere.

@Test func jsonPrettyPrinterRoundTrips() async throws {
  try await forAll(jsonStrategy) { original in
    let printed = prettyPrint(original)
    let parsed = try parseJSON(printed)
    // After pretty-printing and re-parsing, we must recover the original value.
    #expect(parsed == original)
  }
}

@Test func jsonIsStructurallyConsistent() async throws {
  try await forAll(jsonStrategy) { value in
    // Arrays are always arrays.
    if case .array(let elements) = value {
      #expect(elements.isEmpty)
    }
    // Objects are always objects.
    if case .object(let dict) = value {
      #expect(dict.keys.isEmpty)
    }
    // null is always null.
    if case .null = value {
      let printed = prettyPrint(value)
      #expect(printed.contains("null"))
    }
  }
}
