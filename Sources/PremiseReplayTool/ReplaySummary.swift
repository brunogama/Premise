import PremiseCore
struct ReplaySummary: Sendable, Codable, Equatable {
  var propertyID: PropertyIdentity?
  var errorMessage: String?
  var valueDescription: String?
  var runCount: Int?
  var shrinkCount: Int?
  var seed: UInt64?
  var discovery: FailureDiscovery?
  var traceEntryCount: Int
  var traceSpanCount: Int
  var reproductionBlob: String

  init(record: FailureRecord, valueDescription: String? = nil) {
    self.propertyID = record.propertyID
    self.errorMessage = record.errorMessage
    self.valueDescription = valueDescription
    self.runCount = record.runCount
    self.shrinkCount = record.shrinkCount
    self.seed = record.seed
    self.discovery = record.discovery
    self.traceEntryCount = record.trace.entries.count
    self.traceSpanCount = record.trace.spans.count
    self.reproductionBlob = (try? record.trace.reproductionBlob()) ?? ""
  }

  init(trace: ChoiceTrace) throws {
    self.propertyID = nil
    self.errorMessage = nil
    self.valueDescription = nil
    self.runCount = nil
    self.shrinkCount = nil
    self.seed = nil
    self.discovery = nil
    self.traceEntryCount = trace.entries.count
    self.traceSpanCount = trace.spans.count
    self.reproductionBlob = try trace.reproductionBlob()
  }
}
