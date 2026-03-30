import PremiseParallel
import PremiseStrategies

// ❌ UNSAFE: mutating a captured variable without synchronisation.
// Swift 6 rejects this at compile time because `var counter` is not Sendable
// when captured by a @Sendable closure.

// var counter = 0   // ← Swift 6 error: mutation of captured variable 'counter'
//                   //   from a @Sendable closure is not permitted
// let result = try await runner.run { value in
//     counter += 1  // data race: multiple tasks write to counter concurrently
// }

// ✅ Fix: use an actor for shared mutable state.
actor SafeCounter {
  private(set) var count = 0
  func increment() { count += 1 }
}
// let safeCounter = SafeCounter()
// let result = try await runner.run { value in
//     await safeCounter.increment()   // serialised through the actor
// }
