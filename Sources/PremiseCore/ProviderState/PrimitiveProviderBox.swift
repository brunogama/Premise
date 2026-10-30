final class PrimitiveProviderBox<Provider: PrimitiveProvider>:
  PrimitiveProviderBoxBase, @unchecked Sendable
{
  private var provider: Provider

  init(_ provider: Provider) { self.provider = provider }

  override var isExhausted: Bool { provider.isExhausted }
  override func drawBits(count: Int) -> UInt64 {
    provider.drawBits(count: count)
  }
  override func drawBytes(count: Int) -> [UInt8] {
    provider.drawBytes(count: count)
  }
  override func copy() -> PrimitiveProviderBoxBase {
    PrimitiveProviderBox(provider)
  }
}
