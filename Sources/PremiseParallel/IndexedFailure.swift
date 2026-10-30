import PremiseCore
/// Failure record paired with the drawn value for result normalization.
struct IndexedFailure<Value: Sendable>: Sendable {
  let record: FailureRecord
  let value: Value
}
