import Foundation

public struct MenuBarState: Equatable, Sendable {
    public private(set) var isGenerating: Bool
    public private(set) var isPaused: Bool
    public private(set) var lastGeneratedAt: Date?
    public private(set) var recentErrorSummary: String?

    public init(
        isGenerating: Bool = false,
        isPaused: Bool = false,
        lastGeneratedAt: Date? = nil,
        recentErrorSummary: String? = nil
    ) {
        self.isGenerating = isGenerating
        self.isPaused = isPaused
        self.lastGeneratedAt = lastGeneratedAt
        self.recentErrorSummary = recentErrorSummary
    }

    @discardableResult
    public mutating func beginManualGeneration() -> Bool {
        guard !isGenerating else {
            return false
        }

        isGenerating = true
        recentErrorSummary = nil
        return true
    }

    public mutating func finishSuccessfully(at date: Date = Date()) {
        isGenerating = false
        lastGeneratedAt = date
        recentErrorSummary = nil
    }

    public mutating func finishWithFailure(_ message: String) {
        isGenerating = false
        recentErrorSummary = Self.summarize(message)
    }

    public mutating func finishCancelled() {
        isGenerating = false
        recentErrorSummary = nil
    }

    public mutating func setPaused(_ paused: Bool) {
        isPaused = paused
    }

    public func shouldRunAutomaticUpdate(settings: AppSettings, now: Date) -> Bool {
        guard settings.autoUpdateEnabled, !isPaused, !isGenerating else {
            return false
        }

        guard let lastGeneratedAt else {
            return true
        }

        let interval = TimeInterval(max(1, settings.refreshIntervalHours) * 3_600)
        return now.timeIntervalSince(lastGeneratedAt) >= interval
    }

    public var statusTitle: String {
        if isGenerating {
            return "Generating..."
        }

        if isPaused {
            return "Paused"
        }

        if let recentErrorSummary {
            return "Failed: \(recentErrorSummary)"
        }

        return "Idle"
    }

    private static func summarize(_ message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 120 else {
            return trimmed
        }

        let prefix = trimmed.prefix(117)
        return "\(prefix)..."
    }
}
