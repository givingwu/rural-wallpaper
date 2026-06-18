import Foundation

public enum WallpaperJobError: Error, Equatable, Sendable {
    case invalidTransition
}

extension WallpaperJobError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidTransition:
            return "Wallpaper job received an invalid state transition."
        }
    }
}

public enum WallpaperJobStage: String, Codable, Equatable, Sendable {
    case pending
    case makingSource
    case extractingWords
    case analyzingImage
    case planningLayout
    case rendering
    case evaluating
    case settingWallpaper
    case recordingHistory
    case succeeded
    case failed
    case cancelled
}

public enum WallpaperJobTransition: String, Codable, Equatable, Sendable {
    case start
    case sourceReady
    case wordsExtracted
    case analysisReady
    case layoutSelected
    case rendered
    case evaluationRejected
    case evaluationAccepted
    case retryBackground
    case wallpaperSet
    case historyRecorded
    case fail
    case cancel
}

public struct WallpaperJobStateMachine: Equatable, Sendable {
    public private(set) var stage: WallpaperJobStage

    public init(stage: WallpaperJobStage = .pending) {
        self.stage = stage
    }

    @discardableResult
    public mutating func apply(_ transition: WallpaperJobTransition) throws -> WallpaperJobStage {
        guard let nextStage = nextStage(for: transition) else {
            throw WallpaperJobError.invalidTransition
        }

        stage = nextStage
        return nextStage
    }

    private func nextStage(for transition: WallpaperJobTransition) -> WallpaperJobStage? {
        switch (stage, transition) {
        case (.pending, .start):
            return .makingSource
        case (.makingSource, .sourceReady):
            return .extractingWords
        case (.extractingWords, .wordsExtracted):
            return .analyzingImage
        case (.analyzingImage, .analysisReady):
            return .planningLayout
        case (.planningLayout, .layoutSelected):
            return .rendering
        case (.rendering, .rendered):
            return .evaluating
        case (.evaluating, .evaluationRejected):
            return .planningLayout
        case (.planningLayout, .retryBackground):
            return .makingSource
        case (.evaluating, .evaluationAccepted):
            return .settingWallpaper
        case (.settingWallpaper, .wallpaperSet):
            return .recordingHistory
        case (.recordingHistory, .historyRecorded):
            return .succeeded
        case (.pending, .cancel),
             (.makingSource, .cancel),
             (.extractingWords, .cancel),
             (.analyzingImage, .cancel),
             (.planningLayout, .cancel),
             (.rendering, .cancel),
             (.evaluating, .cancel),
             (.settingWallpaper, .cancel),
             (.recordingHistory, .cancel):
            return .cancelled
        case (.pending, .fail),
             (.makingSource, .fail),
             (.extractingWords, .fail),
             (.analyzingImage, .fail),
             (.planningLayout, .fail),
             (.rendering, .fail),
             (.evaluating, .fail),
             (.settingWallpaper, .fail),
             (.recordingHistory, .fail):
            return .failed
        default:
            return nil
        }
    }
}
