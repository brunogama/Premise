import CPremiseSanitizerCoverage
import PremiseCore

/// Runtime access to LLVM SanitizerCoverage edge counters.
///
/// The C shim registers `__sanitizer_cov_trace_pc_guard*` hooks when a client
/// builds with sanitizer-coverage instrumentation. In ordinary builds no guards
/// are registered, so `isAvailable == false` and snapshots return `nil`.
public enum SanitizerCoverage {
  /// Returns true when sanitizer-coverage guards have been registered.
  public static var isAvailable: Bool {
    premise_sancov_edge_count() > 0
  }

  /// Captures the current coverage bitmap, or `nil` when instrumentation is absent.
  public static func snapshot() -> CoverageMap? {
    let edgeCount = Int(premise_sancov_edge_count())
    guard edgeCount > 0 else {
      return nil
    }

    let byteCount = max(1, (edgeCount + 7) / 8)
    var bytes = [UInt8](repeating: 0, count: byteCount)
    let written = bytes.withUnsafeMutableBufferPointer { buffer in
      premise_sancov_snapshot(buffer.baseAddress, UInt32(buffer.count))
    }

    guard written > 0 else {
      return nil
    }

    var map = CoverageMap(capacity: edgeCount)
    for byteIndex in 0..<Int(written) {
      let byte = bytes[byteIndex]
      guard byte != 0 else { continue }
      for bit in 0..<8 where byte & UInt8(1 << bit) != 0 {
        map.recordEdge(byteIndex * 8 + bit)
      }
    }
    return map
  }

  /// Clears recorded edge hits while preserving registered guard IDs.
  public static func reset() {
    premise_sancov_reset()
  }
}

public extension CoverageTracker {
  /// Records the current SanitizerCoverage snapshot if instrumentation exists.
  ///
  /// Returns `nil` in normal, non-instrumented builds so callers can gracefully
  /// fall back to standard pseudo-random generation.
  @discardableResult
  func recordCurrentSanitizerCoverage(trace: ChoiceTrace) async -> CoverageScore? {
    guard let snapshot = SanitizerCoverage.snapshot() else {
      return nil
    }
    return record(snapshot: snapshot, trace: trace)
  }
}
