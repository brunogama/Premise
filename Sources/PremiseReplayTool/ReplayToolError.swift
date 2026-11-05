enum ReplayToolError: Error, CustomStringConvertible {
  case missingInput
  case missingBlob
  case tooManyInputs
  case unrecognizedTraceFile(String)

  var description: String {
    switch self {
    case .missingInput:
      return "missing trace path or reproduction blob"
    case .missingBlob:
      return "--blob requires a reproduction blob argument"
    case .tooManyInputs:
      return "expected at most one trace path or reproduction blob"
    case .unrecognizedTraceFile(let path):
      return "could not decode trace file at \(path)"
    }
  }
}
