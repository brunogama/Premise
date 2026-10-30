struct PrimitiveProviderState: Sendable {
  private var box: PrimitiveProviderBoxBase

  init<Provider: PrimitiveProvider>(_ provider: Provider) {
    box = PrimitiveProviderBox(provider)
  }

  var isExhausted: Bool { box.isExhausted }

  mutating func drawBits(count: Int) -> UInt64 {
    ensureUniqueBox()
    return box.drawBits(count: count)
  }

  mutating func drawBytes(count: Int) -> [UInt8] {
    ensureUniqueBox()
    return box.drawBytes(count: count)
  }

  private mutating func ensureUniqueBox() {
    if !isKnownUniquelyReferenced(&box) {
      box = box.copy()
    }
  }
}
