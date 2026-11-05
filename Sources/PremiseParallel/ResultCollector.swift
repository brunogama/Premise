/// Actor that collects failures from parallel tasks and tracks the
/// earliest (lowest-index) failure for deterministic result ordering.
actor ResultCollector<Value: Sendable> {
  private var earliestIndex: Int?
  private var earliestResult: IndexedFailure<Value>?


  func recordFailure(at index: Int, failure: IndexedFailure<Value>) {
    if let existing = earliestIndex, index >= existing {
      return
    }
    earliestIndex = index
    earliestResult = failure
  }

  func earliestFailure() -> IndexedFailure<Value>? {
    earliestResult
  }
}
