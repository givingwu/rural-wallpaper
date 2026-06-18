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
                if backgroundAttempt > 1 {
                    try machine.apply(.retryBackground)
                }

                let sourceImage = try await sourceProvider.makeSourceImage(for: display, settings: settings)
                context.sourceImageURL = sourceImageURL(from: sourceImage.attribution)
                context.attribution = sourceImage.attribution
                try machine.apply(.sourceReady)

                let words = try await aiProvider.extractWords(from: sourceImage.imageData, countRange: 3...5)
                context.words = words
                try machine.apply(.wordsExtracted)

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
                    context.layout = candidate
                    try machine.apply(.layoutSelected)

                    let rendered = try renderEngine.render(
                        background: sourceImage.imageData,
                        plan: candidate,
                        display: display
                    )
                    context.layout = rendered.layoutPlan
                    try machine.apply(.rendered)

                    let evaluation = try await aiProvider.evaluate(
                        renderedImage: rendered.pngData,
                        plan: rendered.layoutPlan,
                        words: words
                    )
                    context.evaluation = evaluation

                    if evaluation.passes(threshold: minimumScore) {
                        try machine.apply(.evaluationAccepted)
                        let fileURL = try writeRenderedWallpaper(rendered, display: display)
                        let record = context.makeSuccessRecord(finalImageURL: fileURL)

                        try desktopSetter.setWallpaper(fileURL: fileURL, for: display)
                        try machine.apply(.wallpaperSet)

                        try historyStore.append(record)
                        try machine.apply(.historyRecorded)

                        return WallpaperHarnessResult(state: .succeeded, record: record)
                    }

                    context.failureReason = lowScoreFailureReason(
                        score: evaluation.averageScore,
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

    private func lowScoreFailureReason(score: Double, backgroundAttempt: Int) -> String {
        "Rendered layout scored \(formatScore(score)), below minimum \(formatScore(minimumScore)) on background attempt \(backgroundAttempt)."
    }

    private func exhaustedFailureReason(from context: WallpaperHarnessContext) -> String {
        if let evaluation = context.evaluation {
            return "No layout candidate passed after \(maxBackgroundAttempts) background attempt(s). Last score: \(formatScore(evaluation.averageScore)). Minimum required: \(formatScore(minimumScore))."
        }

        return context.failureReason
            ?? "No layout candidate passed after \(maxBackgroundAttempts) background attempt(s)."
    }

    private func failureReason(from error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            return "Wallpaper generation failed: \(description)"
        }

        return "Wallpaper generation failed: \(String(describing: type(of: error)))."
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
}
