import Foundation
import PremiseCore
import PremiseDatabase

/// Primitive provider backed by bytes supplied by an external fuzzer.
///
/// `FuzzInputProvider` consumes bytes in order and pads incomplete primitive
/// draws with zeroes while marking the input as exhausted. This lets strategies
/// use the same ``PremiseData`` draw APIs under libFuzzer, AFL, or other
/// byte-oriented fuzzing engines without adding fuzzer-specific concepts to
/// `PremiseCore`.
public struct FuzzInputProvider: PrimitiveProvider {
  private let bytes: [UInt8]
  private var offset: Int
  private var exhausted: Bool

  /// Creates a provider from raw bytes.
  public init(bytes: [UInt8]) {
    self.bytes = bytes
    offset = 0
    exhausted = false
  }

  /// Creates a provider from Foundation data.
  public init(_ data: Data) {
    self.init(bytes: Array(data))
  }

  /// Number of bytes supplied by the fuzzer.
  public var byteCount: Int { bytes.count }

  /// Number of whole bytes consumed so far.
  public var consumedByteCount: Int { offset }

  /// Number of whole bytes remaining.
  public var remainingByteCount: Int { max(0, bytes.count - offset) }

  public mutating func drawBits(count: Int) -> UInt64 {
    guard count >= 0 else {
      markExhausted()
      return 0
    }

    guard count > 0 else { return 0 }

    let byteCount = min(8, (count + 7) / 8)
    let drawn = drawBytes(count: byteCount)
    var value: UInt64 = 0
    for (index, byte) in drawn.enumerated() {
      value |= UInt64(byte) << UInt64(index * 8)
    }

    guard count < 64 else { return value }
    return value & ((1 << count) - 1)
  }

  public mutating func drawBytes(count: Int) -> [UInt8] {
    guard count >= 0 else {
      markExhausted()
      return []
    }

    guard count > 0 else { return [] }
    guard offset < bytes.count else {
      markExhausted()
      return Array(repeating: 0, count: count)
    }

    let end = min(bytes.count, offset + count)
    let drawn = Array(bytes[offset..<end])
    offset = end

    guard drawn.count == count else {
      markExhausted()
      return drawn + Array(repeating: 0, count: count - drawn.count)
    }

    return drawn
  }

  public mutating func markExhausted() {
    exhausted = true
  }

  public var isExhausted: Bool {
    exhausted
  }
}

/// Outcome of running one external fuzzer input through Premise.
public enum FuzzOutcome: String, Sendable, Codable, Equatable {
  /// The input produced a value and the property did not throw.
  case passed
  /// The strategy or property rejected the input as invalid.
  case rejected
  /// The byte input ran out before Premise could confidently run the property.
  case exhausted
}

/// Result returned by ``fuzzOneInput(_:strategy:config:_:)`` when no failure is found.
public struct FuzzRunResult: Sendable, Codable, Equatable {
  /// Classification of the fuzzer input.
  public let outcome: FuzzOutcome
  /// Number of bytes supplied by the fuzzer.
  public let inputByteCount: Int
  /// Choice trace observed while interpreting the bytes.
  public let trace: ChoiceTrace
  /// Optional rejection reason for invalid inputs.
  public let rejectionReason: String?

  public init(
    outcome: FuzzOutcome,
    inputByteCount: Int,
    trace: ChoiceTrace,
    rejectionReason: String? = nil
  ) {
    self.outcome = outcome
    self.inputByteCount = inputByteCount
    self.trace = trace
    self.rejectionReason = rejectionReason
  }
}

/// Configuration for bridging byte-oriented fuzzers to Premise strategies.
public struct FuzzConfig: Sendable {
  /// Stable identity used when saving failing fuzz inputs.
  public var propertyID: PropertyIdentity
  /// Directory for persisted failure traces. `nil` disables persistence.
  public var databaseDirectory: URL?
  /// Whether failures should be saved to the configured database directory.
  public var saveFailures: Bool

  /// Creates fuzzing configuration.
  public init(
    propertyID: PropertyIdentity = PropertyIdentity(
      fileID: #fileID,
      line: UInt(#line),
      strategyLabel: "fuzz",
      functionName: #function
    ),
    databaseDirectory: URL? = URL(fileURLWithPath: ".premise/fuzz", isDirectory: true),
    saveFailures: Bool = true
  ) {
    self.propertyID = propertyID
    self.databaseDirectory = databaseDirectory
    self.saveFailures = saveFailures
  }

  /// Returns a copy that stores failures under `directory`.
  public func storingFailures(in directory: URL) -> Self {
    var copy = self
    copy.databaseDirectory = directory
    copy.saveFailures = true
    return copy
  }

  /// Returns a copy that does not write failure traces.
  public func withoutPersistence() -> Self {
    var copy = self
    copy.databaseDirectory = nil
    copy.saveFailures = false
    return copy
  }
}

/// Error thrown when a fuzzer input triggers a property failure.
public struct FuzzFailure: Error, Sendable, CustomStringConvertible {
  /// Raw fuzzer input bytes.
  public let input: [UInt8]
  /// Stable property identity used for persistence.
  public let propertyID: PropertyIdentity
  /// Trace that replays the failing strategy choices.
  public let trace: ChoiceTrace
  /// String form of the underlying error.
  public let underlyingDescription: String

  public init(
    input: [UInt8],
    propertyID: PropertyIdentity,
    trace: ChoiceTrace,
    underlyingDescription: String
  ) {
    self.input = input
    self.propertyID = propertyID
    self.trace = trace
    self.underlyingDescription = underlyingDescription
  }

  /// Foundation data view of ``input``.
  public var inputData: Data { Data(input) }

  /// Copy-paste reproduction blob for the failing trace, when encodable.
  public var reproductionBlob: String? { try? trace.reproductionBlob() }

  public var description: String {
    var parts = [
      "Fuzz input failed",
      "property=\(propertyID.fileID):\(propertyID.line)",
      "strategy=\(propertyID.strategyLabel)",
      "bytes=\(input.count)",
      "traceEntries=\(trace.entries.count)",
      "underlying=\(underlyingDescription)",
    ]
    if let reproductionBlob {
      parts.append("reproductionBlob=\(reproductionBlob)")
    }
    return parts.joined(separator: ", ")
  }
}

/// Runs a single byte input from an external fuzzer through a Premise strategy.
///
/// Draw-phase strategy errors and explicit property rejections are treated as
/// invalid fuzz inputs and returned as ``FuzzOutcome/rejected``. If the input
/// runs out while drawing, the property body is skipped and the result is
/// ``FuzzOutcome/exhausted``. Property failures are persisted according to
/// ``FuzzConfig`` and rethrown as ``FuzzFailure``.
@discardableResult
public func fuzzOneInput<Value: Sendable>(
  _ input: Data,
  strategy: Strategy<Value>,
  config: FuzzConfig = FuzzConfig(),
  _ property: @escaping @Sendable (Value) async throws -> Void
) async throws -> FuzzRunResult {
  try await runFuzzOneInput(
    input: input,
    strategy: strategy,
    config: config,
    property: property
  )
}

/// Synchronous-property overload of ``fuzzOneInput(_:strategy:config:_:)``.
@discardableResult
public func fuzzOneInput<Value: Sendable>(
  _ input: Data,
  strategy: Strategy<Value>,
  config: FuzzConfig = FuzzConfig(),
  _ property: @escaping @Sendable (Value) throws -> Void
) async throws -> FuzzRunResult {
  try await runFuzzOneInput(input: input, strategy: strategy, config: config) { value in
    try property(value)
  }
}

/// Byte-array overload for fuzzer integrations that do not use `Data`.
@discardableResult
public func fuzzOneInput<Value: Sendable>(
  bytes: [UInt8],
  strategy: Strategy<Value>,
  config: FuzzConfig = FuzzConfig(),
  _ property: @escaping @Sendable (Value) async throws -> Void
) async throws -> FuzzRunResult {
  try await runFuzzOneInput(
    input: Data(bytes),
    strategy: strategy,
    config: config,
    property: property
  )
}

private func runFuzzOneInput<Value: Sendable>(
  input: Data,
  strategy: Strategy<Value>,
  config: FuzzConfig,
  property: @escaping @Sendable (Value) async throws -> Void
) async throws -> FuzzRunResult {
  let bytes = Array(input)
  var data = PremiseData(provider: FuzzInputProvider(bytes: bytes))

  let value: Value
  do {
    value = try strategy.draw(&data)
  } catch {
    return FuzzRunResult(
      outcome: .rejected,
      inputByteCount: bytes.count,
      trace: data.snapshot(),
      rejectionReason: String(describing: error)
    )
  }

  guard data.status != .exhausted else {
    return FuzzRunResult(
      outcome: .exhausted,
      inputByteCount: bytes.count,
      trace: data.snapshot()
    )
  }

  do {
    try await property(value)
    return FuzzRunResult(
      outcome: .passed,
      inputByteCount: bytes.count,
      trace: data.snapshot()
    )
  } catch is PremiseRejection {
    return FuzzRunResult(
      outcome: .rejected,
      inputByteCount: bytes.count,
      trace: data.snapshot(),
      rejectionReason: "property rejected fuzz input"
    )
  } catch {
    let trace = data.snapshot()
    let failure = FuzzFailure(
      input: bytes,
      propertyID: config.propertyID,
      trace: trace,
      underlyingDescription: String(describing: error)
    )
    try await persist(failure: failure, config: config)
    throw failure
  }
}

private func persist(
  failure: FuzzFailure,
  config: FuzzConfig
) async throws {
  guard config.saveFailures, let directory = config.databaseDirectory else { return }

  let inputData = Data(failure.input)
  let record = FailureRecord(
    propertyID: config.propertyID,
    trace: failure.trace,
    errorMessage: failure.description,
    runCount: 1,
    shrinkCount: 0,
    seed: nil,
    discovery: .newFailure,
    statistics: RunStatistics(
      notes: [
        RunNote(label: "fuzzInputBase64", value: inputData.base64EncodedString()),
        RunNote(label: "fuzzInputByteCount", value: String(failure.input.count)),
      ],
      events: ["fuzz-input-failed"],
      targetScore: nil
    )
  )
  try await FileBackedDatabase(rootDirectory: directory).save(record)
}
