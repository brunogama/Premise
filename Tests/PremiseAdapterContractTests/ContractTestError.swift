/// A simple error type for contract testing.
struct ContractTestError: Error, CustomStringConvertible {
  let message: String
  var description: String { message }
}
