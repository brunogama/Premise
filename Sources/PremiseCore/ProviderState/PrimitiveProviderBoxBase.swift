// The unchecked Sendable boxes are CoW implementation details.
// Each box stores a Sendable PrimitiveProvider; mutation is guarded by
// PrimitiveProviderState.ensureUniqueBox() plus inout PremiseData ownership.
// swiftlint:disable unavailable_function
// Type-erased copy-on-write storage requires reference identity.
// swiftlint:disable:next prefer_struct
class PrimitiveProviderBoxBase: @unchecked Sendable {
  var isExhausted: Bool { fatalError("abstract") }
  func drawBits(count: Int) -> UInt64 { fatalError("abstract") }
  func drawBytes(count: Int) -> [UInt8] { fatalError("abstract") }
  func copy() -> PrimitiveProviderBoxBase { fatalError("abstract") }
}
// swiftlint:enable unavailable_function
