import Foundation
import RuralWallpaperCore

enum GenerateMode: Equatable, Sendable {
    case manual
    case automatic

    var logValue: String {
        switch self {
        case .manual:
            return "manual"
        case .automatic:
            return "automatic"
        }
    }
}

enum GenerateStatusPhase: Equatable, Sendable {
    case idle
    case preparingDisplay
    case readingSource
    case extractingWords
    case renderingPreview
    case applyingWallpaper
    case done
    case failed
    case cancelled
    case timedOut

    var isRunning: Bool {
        switch self {
        case .preparingDisplay, .readingSource, .extractingWords, .renderingPreview, .applyingWallpaper:
            return true
        case .idle, .done, .failed, .cancelled, .timedOut:
            return false
        }
    }

    var displayTitle: String {
        switch self {
        case .idle:
            return "Ready"
        case .preparingDisplay:
            return "Preparing display"
        case .readingSource:
            return "Reading source"
        case .extractingWords:
            return "Extracting words"
        case .renderingPreview:
            return "Rendering preview"
        case .applyingWallpaper:
            return "Applying wallpaper"
        case .done:
            return "Done"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        case .timedOut:
            return "Timed out"
        }
    }
}

enum GenerateSourceKind: Equatable, Sendable {
    case screenWallpaper
    case selectedImage
    case fallbackWallpaper
    case generatedImage
    case unsplashPhoto
    case unknown

    var displayTitle: String {
        switch self {
        case .screenWallpaper:
            return "Screen wallpaper"
        case .selectedImage:
            return "Chosen image"
        case .fallbackWallpaper:
            return "Fallback wallpaper"
        case .generatedImage:
            return "Generated image"
        case .unsplashPhoto:
            return "Unsplash photo"
        case .unknown:
            return "Unknown source"
        }
    }
}

struct GenerateSourceSummary: Equatable, Sendable {
    var kind: GenerateSourceKind
    var originalURL: URL?
    var workingURL: URL?
    var prompt: String?

    var menuLine: String {
        if let detail = detailText {
            return "Source: \(kind.displayTitle) · \(detail)"
        }

        return "Source: \(kind.displayTitle)"
    }

    private var detailText: String? {
        if let originalURL {
            return originalURL.lastPathComponent
        }

        if let prompt,
           !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return workingURL?.lastPathComponent
    }
}

struct GenerateTargetSummary: Equatable, Sendable {
    var displayName: String
    var displayID: String
    var pixelSize: PixelSize

    init(displayName: String, displayID: String, pixelSize: PixelSize) {
        self.displayName = displayName
        self.displayID = displayID
        self.pixelSize = pixelSize
    }

    init(display: DisplayTarget) {
        self.displayName = display.friendlyName
        self.displayID = display.id
        self.pixelSize = display.pixelSize
    }

    var menuLine: String {
        "Target: \(displayName) · \(pixelSize.width)x\(pixelSize.height)"
    }
}

struct GenerateStatus: Equatable, Sendable {
    var runID: String?
    var phase: GenerateStatusPhase
    var mode: GenerateMode?
    var startedAt: Date?
    var finishedAt: Date?
    var timeoutSeconds: TimeInterval?
    var source: GenerateSourceSummary?
    var target: GenerateTargetSummary?
    var previewURL: URL?
    var wordCount: Int?
    var errorSummary: String?

    static func idle() -> GenerateStatus {
        GenerateStatus(
            runID: nil,
            phase: .idle,
            mode: nil,
            startedAt: nil,
            finishedAt: nil,
            timeoutSeconds: nil,
            source: nil,
            target: nil,
            previewURL: nil,
            wordCount: nil,
            errorSummary: nil
        )
    }

    func primaryLine(now: Date = Date()) -> String {
        switch phase {
        case .idle:
            return "Ready"
        case .preparingDisplay, .readingSource, .extractingWords, .renderingPreview, .applyingWallpaper:
            return runningLine(now: now)
        case .done:
            return doneLine(now: now)
        case .failed:
            return terminalLine(title: "Failed", now: now)
        case .cancelled:
            return "Cancelled · \(elapsedText(now: now))"
        case .timedOut:
            let summary = errorSummary ?? "Generation"
            return "Timed out · \(summary) · \(Self.formatDuration(timeoutSeconds ?? elapsedSeconds(now: now)))"
        }
    }

    var sourceLine: String? {
        source?.menuLine
    }

    var targetLine: String? {
        target?.menuLine
    }

    var previewLine: String? {
        previewURL.map { "Preview: \($0.lastPathComponent)" }
    }

    func elapsedSeconds(now: Date = Date()) -> TimeInterval {
        guard let startedAt else {
            return 0
        }

        let endDate = finishedAt ?? now
        return max(0, endDate.timeIntervalSince(startedAt))
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded(.down)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func runningLine(now: Date) -> String {
        let elapsed = elapsedText(now: now)
        if let timeoutSeconds {
            return "Generating · \(phase.displayTitle) · \(elapsed) / \(Self.formatDuration(timeoutSeconds))"
        }

        return "Generating · \(phase.displayTitle) · \(elapsed)"
    }

    private func doneLine(now: Date) -> String {
        let words = wordCount.map { " · \($0) words" } ?? ""
        return "Done · \(elapsedText(now: now))\(words)"
    }

    private func terminalLine(title: String, now: Date) -> String {
        if let errorSummary,
           !errorSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(title) · \(errorSummary) · \(elapsedText(now: now))"
        }

        return "\(title) · \(elapsedText(now: now))"
    }

    private func elapsedText(now: Date) -> String {
        Self.formatDuration(elapsedSeconds(now: now))
    }
}
