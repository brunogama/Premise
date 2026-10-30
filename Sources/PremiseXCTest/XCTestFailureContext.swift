import PremiseCore

struct XCTestFailureContext {
  let record: FailureRecord
  let propertyID: PropertyIdentity
  var report: RunReport?
  var includeReproductionBlob = false
}
