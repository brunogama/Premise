enum StateMachineTestError: Error, CustomStringConvertible, Sendable {
  case bundleLeak
  case invariantFailure
  case referenceStateLeak
  case ruleFailure
  case teardownFailure
  case unexpectedDraw

  var description: String {
    switch self {
    case .bundleLeak: return "bundle leaked values"
    case .invariantFailure: return "invariant failed"
    case .referenceStateLeak: return "reference-backed state leaked"
    case .ruleFailure: return "rule failed"
    case .teardownFailure: return "teardown failed"
    case .unexpectedDraw: return "unexpected draw failure"
    }
  }
}
