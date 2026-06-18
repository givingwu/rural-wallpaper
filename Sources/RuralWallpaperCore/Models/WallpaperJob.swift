import Foundation

public enum WallpaperJobState: String, Codable, Equatable, Sendable {
    case pending
    case running
    case succeeded
    case failed
    case cancelled
}

public struct WallpaperJob: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public var display: DisplayTarget
    public var state: WallpaperJobState
    public var attempts: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        display: DisplayTarget,
        state: WallpaperJobState = .pending,
        attempts: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.display = display
        self.state = state
        self.attempts = attempts
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
