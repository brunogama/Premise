#if canImport(XCTest)
import PremiseCore

struct XCTestRunOptions<Value: Sendable> {
  let config: PropertyConfig
  let explicitExamples: [Value]
  let examples: [ExplicitExample<Value>]
  let fileID: String
  let file: StaticString
  let line: UInt
  let function: String
}
#endif
