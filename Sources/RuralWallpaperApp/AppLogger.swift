import Foundation

final class AppLogger: @unchecked Sendable {
    let logFileURL: URL
    private let lock = NSLock()
    private let timestampFormatter: ISO8601DateFormatter

    init(logFileURL: URL) {
        self.logFileURL = logFileURL
        self.timestampFormatter = ISO8601DateFormatter()
        self.timestampFormatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        try? FileManager.default.createDirectory(
            at: logFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }
    }

    func info(_ message: String) {
        write(level: "INFO", message)
    }

    func error(_ message: String) {
        write(level: "ERROR", message)
    }

    private func write(level: String, _ message: String) {
        let line = "\(timestampFormatter.string(from: Date())) [\(level)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        lock.lock()
        defer { lock.unlock() }

        do {
            let handle = try FileHandle(forWritingTo: logFileURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
        } catch {
            try? data.write(to: logFileURL, options: .atomic)
        }
    }
}
