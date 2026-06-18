import Foundation

public protocol SettingsStore: Sendable {
    func load() throws -> AppSettings
    func save(_ settings: AppSettings) throws
}

public enum SettingsStoreError: Error, Equatable, LocalizedError, Sendable {
    case failedToEncodeSettings(String)
    case failedToDecodeSettings(String)

    public var errorDescription: String? {
        switch self {
        case .failedToEncodeSettings(let detail):
            "Failed to encode app settings: \(detail)"
        case .failedToDecodeSettings(let detail):
            "Failed to decode saved app settings: \(detail)"
        }
    }
}
