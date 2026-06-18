import Foundation

public enum HistoryStoreError: Error, Equatable, Sendable {
    case failedToCreateDirectory(URL)
    case failedToRead(URL)
    case failedToDecode(URL)
    case failedToEncode
    case failedToWrite(URL)
    case sensitiveDataDetected(String)
}

public protocol HistoryStore: Sendable {
    func append(_ record: GeneratedWallpaper) throws
    func recent(displayID: String, limit: Int) throws -> [GeneratedWallpaper]
}
