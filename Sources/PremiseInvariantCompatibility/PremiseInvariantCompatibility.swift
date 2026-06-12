@_exported import PremiseCore
@_exported import PremiseStrategies
@_exported import PremiseTesting

/// Namespace marker for the optional migration compatibility target.
public enum PremiseInvariantCompatibilityModule {
  public static let name = "PremiseInvariantCompatibility"
}

@available(*, deprecated, message: "Use Strategy instead.")
public typealias Gen<Value: Sendable> = Strategy<Value>

@available(*, deprecated, message: "Use Strategy instead.")
public typealias Generator<Value: Sendable> = Strategy<Value>

@available(*, deprecated, message: "Use Strategy instead.")
public typealias AnyGenerator<Value: Sendable> = Strategy<Value>

@available(*, deprecated, message: "Use Runner instead.")
public typealias PropertyRunner<Value: Sendable> = Runner<Value>

@available(*, deprecated, message: "Use UInt64 seeds directly or PropertyConfig.seed(_:).")
public typealias Seed = UInt64

@available(*, deprecated, message: "Use Int size budgets directly or Strategy.sized(maxSize:_:).")
public typealias Size = Int

@available(*, deprecated, message: "Use Strategy.shrinking(_:) instead.")
public typealias Shrink<Value: Sendable> = @Sendable (Value) -> [Value]

@available(*, deprecated, message: "Use expectForAll or forAll instead.")
public typealias Property<Value: Sendable> = @Sendable (Value) -> Bool

@available(*, deprecated, message: "Use expectForAll or forAll instead.")
public typealias ThrowingProperty<Value: Sendable> = @Sendable (Value) throws -> Bool

@available(*, deprecated, message: "Use async expectForAll or forAll instead.")
public typealias AsyncThrowingProperty<Value: Sendable> = @Sendable (Value) async throws -> Bool

@available(*, deprecated, message: "Use zip(_:_:) instead.")
public typealias Zip2Generator<A: Sendable, B: Sendable> = Strategy<(A, B)>

@available(*, deprecated, message: "Use zip(_:_:_:) instead.")
public typealias Zip3Generator<A: Sendable, B: Sendable, C: Sendable> = Strategy<(A, B, C)>

@available(*, deprecated, message: "Use custom tuple strategies instead.")
public typealias Zip4Generator<A: Sendable, B: Sendable, C: Sendable, D: Sendable> = Strategy<
  (
    A, B, C, D
  )
>
