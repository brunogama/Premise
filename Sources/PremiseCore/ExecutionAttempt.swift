enum ExecutionAttempt<Value: Sendable> {
  case passed(RunStatistics, ChoiceTrace)
  case rejected(RejectionKind, RunStatistics, ChoiceTrace)
  case failure(ExecutionFailure<Value>)
}
