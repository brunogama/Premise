import Foundation

public enum ConjectureCoreModule {
    public static let name = "ConjectureCore"
}

/// Minimal persisted failure envelope shared between the core and storage.
public struct FailureRecord: Sendable, Codable, Equatable {
    public var propertyID: PropertyIdentity
    public var trace: ChoiceTrace
    public var errorMessage: String
    public var runCount: Int
    public var shrinkCount: Int
    public var timestamp: Date
    public var engineVersion: String

    public init(
        propertyID: PropertyIdentity,
        trace: ChoiceTrace,
        errorMessage: String,
        runCount: Int = 0,
        shrinkCount: Int = 0,
        timestamp: Date = .init(timeIntervalSince1970: 0),
        engineVersion: String = "0.2.0"
    ) {
        self.propertyID = propertyID
        self.trace = trace
        self.errorMessage = errorMessage
        self.runCount = runCount
        self.shrinkCount = shrinkCount
        self.timestamp = timestamp
        self.engineVersion = engineVersion
    }
}
