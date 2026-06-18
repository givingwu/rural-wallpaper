import Foundation

public protocol HistoryStore: Sendable {
    func append(_ record: GeneratedWallpaper) throws
    func recent(displayID: String, limit: Int) throws -> [GeneratedWallpaper]
}
