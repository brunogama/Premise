import ConjectureCore
import Foundation

/// File-backed failure store that persists one JSON file per property identity.
///
/// Records are encoded through ``PersistenceCodec`` into the versioned
/// ``PersistedFailureRecordV1`` envelope. Each property gets a dedicated file
/// under the configured root directory (default `.conjecture/examples`), and
/// all writes use atomic file operations to prevent partial-write corruption.
public actor FileBackedDatabase: ExampleDatabase {
    /// Root directory where property failure files are stored.
    private let rootDirectory: URL

    /// Creates a file-backed database rooted at the given directory.
    ///
    /// - Parameter rootDirectory: Directory where property failure files are
    ///   stored. Defaults to `.conjecture/examples` relative to the current
    ///   working directory. The directory is created with intermediates if it
    ///   does not already exist.
    public init(rootDirectory: URL? = nil) {
        self.rootDirectory =
            rootDirectory
            ?? URL(fileURLWithPath: ".conjecture/examples", isDirectory: true)
    }

    // MARK: - ExampleDatabase

    public func loadTraces(
        for id: PropertyIdentity
    ) async throws -> [ChoiceTrace] {
        let fileURL = propertyFileURL(for: id)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        let envelopes = try JSONDecoder().decode(
            [PersistedFailureRecordV1].self,
            from: data
        )

        return try envelopes.map { envelope in
            let record = try PersistenceCodec.decode(envelope)
            return record.trace
        }
    }

    public func save(_ record: FailureRecord) async throws {
        try ensureDirectoryExists()

        let fileURL = propertyFileURL(for: record.propertyID)
        var envelopes: [PersistedFailureRecordV1] = []

        if FileManager.default.fileExists(atPath: fileURL.path) {
            let existingData = try Data(contentsOf: fileURL)
            envelopes = try JSONDecoder().decode(
                [PersistedFailureRecordV1].self,
                from: existingData
            )
        }

        let encoded = PersistenceCodec.encode(record)
        envelopes.append(encoded)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(envelopes)
        try data.write(to: fileURL, options: [.atomic])
    }

    public func clear(for id: PropertyIdentity) async throws {
        let fileURL = propertyFileURL(for: id)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        try FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Private Helpers

    /// Builds the file URL for a given property identity.
    ///
    /// File names are the hex-encoded UTF-8 bytes of
    /// `"\(fileID)#\(line)#\(strategyLabel)"` with a `.json` extension.
    private func propertyFileURL(for id: PropertyIdentity) -> URL {
        let key = "\(id.fileID)#\(id.line)#\(id.strategyLabel)"
        let hexName = Data(key.utf8).map { String(format: "%02x", $0) }
            .joined()
        return rootDirectory.appendingPathComponent("\(hexName).json")
    }

    /// Ensures the root directory exists, creating intermediate directories
    /// as needed.
    private func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(
            at: rootDirectory,
            withIntermediateDirectories: true
        )
    }
}
