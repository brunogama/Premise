import Foundation
import PremiseCore

final class StateMachineRunContext: @unchecked Sendable {
  // TaskLocal values must be Sendable and rule closures are @Sendable.
  // The unchecked conformance is valid only because every access
  // to mutable bundle storage is serialized by this lock.
  private let lock = NSLock()
  private var storage: [StateMachineBundleKey: [any Sendable]] = [:]

  func selectValue<Element: Sendable>(
    for key: StateMachineBundleKey,
    consuming: Bool,
    using data: inout PremiseData
  ) -> Element? {
    lock.lock()
    defer { lock.unlock() }

    guard let values = storage[key] else { return nil }
    let typedValues: [(offset: Int, value: Element)] =
      values.enumerated().compactMap { offset, value in
        guard let element = value as? Element else { return nil }
        return (offset, element)
      }
    guard !typedValues.isEmpty else { return nil }

    let selectedIndex = data.drawInteger(in: 0...(typedValues.count - 1))
    let selected = typedValues[selectedIndex]
    if consuming {
      storage[key]?.remove(at: selected.offset)
    }
    return selected.value
  }

  func append<Element: Sendable>(
    _ element: Element,
    to bundle: StateMachineBundle<Element>
  ) {
    lock.lock()
    defer { lock.unlock() }

    storage[bundle.key, default: []].append(element)
  }
}
