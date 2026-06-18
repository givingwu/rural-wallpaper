public struct AppSettings: Codable, Equatable, Sendable {
    public var autoUpdateEnabled: Bool
    public var refreshIntervalHours: Int
    public var maxBackgroundAttempts: Int
    public var maxLayoutCandidates: Int
    public var minimumScore: Double
    public var historyLimitPerDisplay: Int
    public var preferredThemes: [String]
    public var enabledDisplayIDs: Set<String>

    public init(
        autoUpdateEnabled: Bool,
        refreshIntervalHours: Int,
        maxBackgroundAttempts: Int,
        maxLayoutCandidates: Int,
        minimumScore: Double,
        historyLimitPerDisplay: Int,
        preferredThemes: [String],
        enabledDisplayIDs: Set<String>
    ) {
        self.autoUpdateEnabled = autoUpdateEnabled
        self.refreshIntervalHours = refreshIntervalHours
        self.maxBackgroundAttempts = maxBackgroundAttempts
        self.maxLayoutCandidates = maxLayoutCandidates
        self.minimumScore = minimumScore
        self.historyLimitPerDisplay = historyLimitPerDisplay
        self.preferredThemes = preferredThemes
        self.enabledDisplayIDs = enabledDisplayIDs
    }

    public static let `default` = AppSettings(
        autoUpdateEnabled: false,
        refreshIntervalHours: 24,
        maxBackgroundAttempts: 3,
        maxLayoutCandidates: 5,
        minimumScore: 0.75,
        historyLimitPerDisplay: 30,
        preferredThemes: ["rural", "nature", "calm"],
        enabledDisplayIDs: []
    )
}
