public struct AppSettings: Codable, Equatable, Sendable {
    public static let defaultVocabularyWordCount = 6
    public static let defaultWallpaperWordLimit = 6
    public static let vocabularyWordCountRange = 3...24
    public static let wallpaperWordLimitRange = 1...12

    public var autoUpdateEnabled: Bool
    public var refreshIntervalHours: Int
    public var maxBackgroundAttempts: Int
    public var maxLayoutCandidates: Int
    public var minimumScore: Double
    public var historyLimitPerDisplay: Int
    public var preferredThemes: [String]
    public var enabledDisplayIDs: Set<String>
    public var selectedPreviewDisplayID: String?
    public var vocabularyWordCount: Int {
        didSet {
            vocabularyWordCount = Self.clampedVocabularyWordCount(vocabularyWordCount)
        }
    }
    public var wallpaperWordLimit: Int {
        didSet {
            wallpaperWordLimit = Self.clampedWallpaperWordLimit(wallpaperWordLimit)
        }
    }

    public init(
        autoUpdateEnabled: Bool,
        refreshIntervalHours: Int,
        maxBackgroundAttempts: Int,
        maxLayoutCandidates: Int,
        minimumScore: Double,
        historyLimitPerDisplay: Int,
        preferredThemes: [String],
        enabledDisplayIDs: Set<String>,
        selectedPreviewDisplayID: String? = nil,
        vocabularyWordCount: Int = Self.defaultVocabularyWordCount,
        wallpaperWordLimit: Int = Self.defaultWallpaperWordLimit
    ) {
        self.autoUpdateEnabled = autoUpdateEnabled
        self.refreshIntervalHours = refreshIntervalHours
        self.maxBackgroundAttempts = maxBackgroundAttempts
        self.maxLayoutCandidates = maxLayoutCandidates
        self.minimumScore = minimumScore
        self.historyLimitPerDisplay = historyLimitPerDisplay
        self.preferredThemes = preferredThemes
        self.enabledDisplayIDs = enabledDisplayIDs
        self.selectedPreviewDisplayID = selectedPreviewDisplayID
        self.vocabularyWordCount = Self.clampedVocabularyWordCount(vocabularyWordCount)
        self.wallpaperWordLimit = Self.clampedWallpaperWordLimit(wallpaperWordLimit)
    }

    public static let `default` = AppSettings(
        autoUpdateEnabled: false,
        refreshIntervalHours: 24,
        maxBackgroundAttempts: 3,
        maxLayoutCandidates: 5,
        minimumScore: 0.75,
        historyLimitPerDisplay: 30,
        preferredThemes: ["rural", "nature", "calm"],
        enabledDisplayIDs: [],
        selectedPreviewDisplayID: nil,
        vocabularyWordCount: defaultVocabularyWordCount,
        wallpaperWordLimit: defaultWallpaperWordLimit
    )

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            autoUpdateEnabled: try container.decode(Bool.self, forKey: .autoUpdateEnabled),
            refreshIntervalHours: try container.decode(Int.self, forKey: .refreshIntervalHours),
            maxBackgroundAttempts: try container.decode(Int.self, forKey: .maxBackgroundAttempts),
            maxLayoutCandidates: try container.decode(Int.self, forKey: .maxLayoutCandidates),
            minimumScore: try container.decode(Double.self, forKey: .minimumScore),
            historyLimitPerDisplay: try container.decode(Int.self, forKey: .historyLimitPerDisplay),
            preferredThemes: try container.decode([String].self, forKey: .preferredThemes),
            enabledDisplayIDs: try container.decode(Set<String>.self, forKey: .enabledDisplayIDs),
            selectedPreviewDisplayID: try container.decodeIfPresent(
                String.self,
                forKey: .selectedPreviewDisplayID
            ),
            vocabularyWordCount: try container.decodeIfPresent(
                Int.self,
                forKey: .vocabularyWordCount
            ) ?? Self.defaultVocabularyWordCount,
            wallpaperWordLimit: try container.decodeIfPresent(
                Int.self,
                forKey: .wallpaperWordLimit
            ) ?? Self.defaultWallpaperWordLimit
        )
    }

    public static func clampedVocabularyWordCount(_ value: Int) -> Int {
        min(max(value, vocabularyWordCountRange.lowerBound), vocabularyWordCountRange.upperBound)
    }

    public static func clampedWallpaperWordLimit(_ value: Int) -> Int {
        min(max(value, wallpaperWordLimitRange.lowerBound), wallpaperWordLimitRange.upperBound)
    }
}
