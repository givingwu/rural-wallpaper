import Foundation

public final class FileHistoryStore: HistoryStore, @unchecked Sendable {
    private let storageURL: URL
    private let retentionLimitPerDisplay: Int
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let lock = NSLock()

    public init(
        storageURL: URL,
        retentionLimitPerDisplay: Int = 30,
        fileManager: FileManager = .default
    ) {
        self.storageURL = storageURL
        self.retentionLimitPerDisplay = max(1, retentionLimitPerDisplay)
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    public func append(_ record: GeneratedWallpaper) throws {
        try lock.withLock {
            var records = try loadRecords()
            records.append(record)
            records = prunedRecords(records)
            let data = try encode(records)
            try validateNoSensitiveData(in: data)
            try write(data)
        }
    }

    public func recent(displayID: String, limit: Int) throws -> [GeneratedWallpaper] {
        try lock.withLock {
            let boundedLimit = max(0, limit)
            guard boundedLimit > 0 else {
                return []
            }

            return try loadRecords()
                .filter { $0.display.id == displayID }
                .sortedByCreatedAtDescending()
                .prefix(boundedLimit)
                .map { $0 }
        }
    }

    private func loadRecords() throws -> [GeneratedWallpaper] {
        guard fileManager.fileExists(atPath: storageURL.path) else {
            return []
        }

        let data: Data
        do {
            data = try Data(contentsOf: storageURL)
        } catch {
            throw HistoryStoreError.failedToRead(storageURL)
        }

        do {
            return try decoder.decode([GeneratedWallpaper].self, from: data)
        } catch {
            throw HistoryStoreError.failedToDecode(storageURL)
        }
    }

    private func prunedRecords(_ records: [GeneratedWallpaper]) -> [GeneratedWallpaper] {
        let groups = Dictionary(grouping: records, by: { $0.display.id })

        return groups.values
            .flatMap { group in
                group
                    .sortedByCreatedAtDescending()
                    .prefix(retentionLimitPerDisplay)
            }
            .sortedByCreatedAtDescending()
    }

    private func encode(_ records: [GeneratedWallpaper]) throws -> Data {
        do {
            return try encoder.encode(records)
        } catch {
            throw HistoryStoreError.failedToEncode
        }
    }

    private func validateNoSensitiveData(in data: Data) throws {
        guard let json = String(data: data, encoding: .utf8) else {
            throw HistoryStoreError.failedToEncode
        }

        let checks: [(String, String.CompareOptions)] = [
            ("Bearer ", [.caseInsensitive]),
            ("apiKey", [.caseInsensitive]),
            (#"sk-[A-Za-z0-9_-]{6,}"#, [.regularExpression, .caseInsensitive])
        ]

        for (pattern, options) in checks where json.range(of: pattern, options: options) != nil {
            throw HistoryStoreError.sensitiveDataDetected(pattern)
        }
    }

    private func write(_ data: Data) throws {
        do {
            try fileManager.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            throw HistoryStoreError.failedToCreateDirectory(storageURL.deletingLastPathComponent())
        }

        do {
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            throw HistoryStoreError.failedToWrite(storageURL)
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer {
            unlock()
        }

        return try body()
    }
}

private extension Array where Element == GeneratedWallpaper {
    func sortedByCreatedAtDescending() -> [GeneratedWallpaper] {
        sorted {
            if $0.createdAt == $1.createdAt {
                return $0.id > $1.id
            }

            return $0.createdAt > $1.createdAt
        }
    }
}
