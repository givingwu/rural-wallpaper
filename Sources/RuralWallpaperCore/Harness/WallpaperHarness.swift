import Foundation

public struct WallpaperHarnessResult: Equatable, Sendable {
    public var state: WallpaperJobState
    public var record: GeneratedWallpaper

    public init(state: WallpaperJobState, record: GeneratedWallpaper) {
        self.state = state
        self.record = record
    }
}

public struct WallpaperHarness: Sendable {
    private let sourceProvider: any SourceProvider
    private let aiProvider: any AIProvider
    private let layoutPlanner: any LayoutPlanner
    private let renderEngine: any RenderEngine
    private let desktopSetter: any DesktopWallpaperSetter
    private let historyStore: any HistoryStore
    private let outputDirectory: URL
    private let settings: AppSettings

    public init(
        sourceProvider: any SourceProvider,
        aiProvider: any AIProvider,
        layoutPlanner: any LayoutPlanner,
        renderEngine: any RenderEngine,
        desktopSetter: any DesktopWallpaperSetter,
        historyStore: any HistoryStore,
        outputDirectory: URL,
        settings: AppSettings = .default
    ) {
        self.sourceProvider = sourceProvider
        self.aiProvider = aiProvider
        self.layoutPlanner = layoutPlanner
        self.renderEngine = renderEngine
        self.desktopSetter = desktopSetter
        self.historyStore = historyStore
        self.outputDirectory = outputDirectory
        self.settings = settings
    }

    public func run(display: DisplayTarget) async throws -> WallpaperHarnessResult {
        var machine = WallpaperJobStateMachine()
        var context = WallpaperHarnessContext(display: display, providerID: sourceProvider.id)

        do {
            try machine.apply(.start)

            for backgroundAttempt in 1...maxBackgroundAttempts {
                try Task.checkCancellation()

                if backgroundAttempt > 1 {
                    try machine.apply(.retryBackground)
                }

                context = WallpaperHarnessContext(display: display, providerID: sourceProvider.id)

                let sourceImage = try await sourceProvider.makeSourceImage(for: display, settings: settings)
                context.sourceImageURL = sourceImageURL(from: sourceImage.attribution)
                context.attribution = sourceImage.attribution
                try machine.apply(.sourceReady)

                try Task.checkCancellation()
                let words = try await aiProvider.extractWords(from: sourceImage.imageData, countRange: 3...5)
                guard isValidWordCount(words) else {
                    context.failureReason = invalidWordCountFailureReason(
                        count: words.count,
                        backgroundAttempt: backgroundAttempt
                    )
                    continue
                }

                context.words = words
                try machine.apply(.wordsExtracted)

                try Task.checkCancellation()
                let analysis = try await aiProvider.analyzeImage(sourceImage.imageData, display: display)
                try machine.apply(.analysisReady)

                let candidates = Array(
                    layoutPlanner.makeLayoutCandidates(
                        display: display,
                        analysis: analysis,
                        words: words,
                        maxCandidates: maxLayoutCandidates
                    )
                    .prefix(maxLayoutCandidates)
                )

                guard !candidates.isEmpty else {
                    context.failureReason = "No layout candidates were produced for background attempt \(backgroundAttempt)."
                    continue
                }

                for candidate in candidates {
                    try Task.checkCancellation()

                    context.layout = candidate
                    context.evaluation = nil
                    try machine.apply(.layoutSelected)

                    let rendered = try renderEngine.render(
                        background: sourceImage.imageData,
                        plan: candidate,
                        display: display
                    )
                    context.layout = rendered.layoutPlan
                    try machine.apply(.rendered)

                    try Task.checkCancellation()
                    let evaluation = try await aiProvider.evaluate(
                        renderedImage: rendered.pngData,
                        plan: rendered.layoutPlan,
                        words: words
                    )
                    context.evaluation = evaluation

                    if evaluation.passes(threshold: minimumScore) {
                        try machine.apply(.evaluationAccepted)
                        try Task.checkCancellation()

                        let fileURL = try writeRenderedWallpaper(rendered, display: display)
                        let record = context.makeSuccessRecord(finalImageURL: fileURL)

                        try Task.checkCancellation()
                        try desktopSetter.setWallpaper(fileURL: fileURL, for: display)
                        try machine.apply(.wallpaperSet)

                        try historyStore.append(record)
                        try machine.apply(.historyRecorded)

                        return WallpaperHarnessResult(state: .succeeded, record: record)
                    }

                    context.failureReason = evaluationFailureReason(
                        evaluation,
                        backgroundAttempt: backgroundAttempt
                    )
                    try machine.apply(.evaluationRejected)
                }
            }

            try machine.apply(.fail)
            let record = context.makeFailureRecord(
                failureReason: exhaustedFailureReason(from: context)
            )
            try historyStore.append(record)

            return WallpaperHarnessResult(state: .failed, record: record)
        } catch {
            if isCancellation(error) {
                if machine.stage != .cancelled {
                    _ = try? machine.apply(.cancel)
                }

                return WallpaperHarnessResult(
                    state: .cancelled,
                    record: context.makeCancelledRecord()
                )
            }

            if machine.stage != .failed {
                _ = try? machine.apply(.fail)
            }

            let record = context.makeFailureRecord(failureReason: failureReason(from: error))
            try historyStore.append(record)

            return WallpaperHarnessResult(state: .failed, record: record)
        }
    }

    private var maxBackgroundAttempts: Int {
        max(1, settings.maxBackgroundAttempts)
    }

    private var maxLayoutCandidates: Int {
        max(1, settings.maxLayoutCandidates)
    }

    private var minimumScore: Double {
        min(max(settings.minimumScore, 0), 1)
    }

    private var minimumTextCorrectness: Double {
        0.95
    }

    private var minimumNoBadOcclusion: Double {
        0.75
    }

    private func isValidWordCount(_ words: [VocabularyItem]) -> Bool {
        (3...5).contains(words.count)
    }

    private func writeRenderedWallpaper(
        _ rendered: RenderedWallpaper,
        display: DisplayTarget
    ) throws -> URL {
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        let fileURL = outputDirectory
            .appendingPathComponent("\(safeFileComponent(display.id))-\(UUID().uuidString)")
            .appendingPathExtension("png")
        try rendered.pngData.write(to: fileURL, options: .atomic)

        return fileURL
    }

    private func sourceImageURL(from attribution: SourceAttribution) -> URL? {
        switch attribution {
        case .aiGenerated:
            return nil
        case .unsplash(let attribution):
            return attribution.sourceURL
        }
    }

    private func invalidWordCountFailureReason(count: Int, backgroundAttempt: Int) -> String {
        "Provider returned word count \(count) outside required 3...5 on background attempt \(backgroundAttempt)."
    }

    private func evaluationFailureReason(
        _ evaluation: EvaluationResult,
        backgroundAttempt: Int
    ) -> String {
        var failedGates: [String] = []

        if evaluation.averageScore < minimumScore {
            failedGates.append(
                "average score \(formatScore(evaluation.averageScore)) below minimum \(formatScore(minimumScore))"
            )
        }

        if evaluation.textCorrectness < minimumTextCorrectness {
            failedGates.append(
                "text correctness \(formatScore(evaluation.textCorrectness)) below minimum \(formatScore(minimumTextCorrectness))"
            )
        }

        if evaluation.noBadOcclusion < minimumNoBadOcclusion {
            failedGates.append(
                "occlusion score \(formatScore(evaluation.noBadOcclusion)) below minimum \(formatScore(minimumNoBadOcclusion))"
            )
        }

        let reason = failedGates.isEmpty
            ? "evaluation did not pass"
            : failedGates.joined(separator: "; ")

        return "Rendered layout failed evaluation on background attempt \(backgroundAttempt): \(reason)."
    }

    private func exhaustedFailureReason(from context: WallpaperHarnessContext) -> String {
        let prefix = "No layout candidate passed after \(maxBackgroundAttempts) background attempt(s)."

        if let failureReason = context.failureReason {
            return "\(prefix) Last attempt: \(failureReason)"
        }

        if let evaluation = context.evaluation {
            return "\(prefix) Last score: \(formatScore(evaluation.averageScore)). Minimum required: \(formatScore(minimumScore))."
        }

        return prefix
    }

    private func failureReason(from error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            return "Wallpaper generation failed: \(description)"
        }

        return "Wallpaper generation failed: \(String(describing: type(of: error)))."
    }

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        if let urlError = error as? URLError {
            return urlError.code == .cancelled
        }

        return false
    }

    private func formatScore(_ score: Double) -> String {
        String(format: "%.2f", score)
    }

    private func safeFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let safe = String(scalars)

        return safe.isEmpty ? "display" : safe
    }
}

private struct WallpaperHarnessContext {
    var display: DisplayTarget
    var providerID: String
    var words: [VocabularyItem] = []
    var layout: LayoutPlan?
    var evaluation: EvaluationResult?
    var attribution: SourceAttribution?
    var sourceImageURL: URL?
    var failureReason: String?

    func makeSuccessRecord(finalImageURL: URL) -> GeneratedWallpaper {
        GeneratedWallpaper(
            finalImageURL: finalImageURL,
            sourceImageURL: sourceImageURL,
            display: display,
            words: words,
            layout: layout,
            evaluation: evaluation,
            attribution: attribution,
            providerID: providerID
        )
    }

    func makeFailureRecord(failureReason: String) -> GeneratedWallpaper {
        GeneratedWallpaper(
            finalImageURL: nil,
            sourceImageURL: sourceImageURL,
            display: display,
            words: words,
            layout: layout,
            evaluation: evaluation,
            attribution: attribution,
            providerID: providerID,
            failureReason: failureReason
        )
    }

    func makeCancelledRecord() -> GeneratedWallpaper {
        GeneratedWallpaper(
            finalImageURL: nil,
            sourceImageURL: sourceImageURL,
            display: display,
            words: words,
            layout: layout,
            evaluation: evaluation,
            attribution: attribution,
            providerID: providerID
        )
    }
}
