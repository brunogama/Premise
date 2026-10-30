enum MacroError: Error, CustomStringConvertible {
  case notAFunction
  case missingStrategies
  case missingBody
  case arityMismatch(strategies: Int, params: Int)

  var description: String {
    switch self {
    case .notAFunction:
      return "@given can only be applied to functions"

    case .missingStrategies:
      return "@given requires at least one strategy argument"

    case .missingBody:
      return "@given requires a function with a body"

    case .arityMismatch(let strategies, let parameters):
      return "@given has \(strategies) strategies but function has \(parameters) parameters"
    }
  }
}
