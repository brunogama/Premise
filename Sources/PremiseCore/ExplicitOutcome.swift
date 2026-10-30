enum ExplicitOutcome {
  case passed
  case rejected
  case failure(String)
  case deadline(String)
}
