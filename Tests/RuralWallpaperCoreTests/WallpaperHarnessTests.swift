import Foundation
import XCTest
@testable import RuralWallpaperCore

final class WallpaperHarnessTests: XCTestCase {
    func testSuccessfulPathSetsDesktopAndRecordsHistory() async throws {
        let outputDirectory = try makeTemporaryDirectory()
        let display = makeDisplay(id: "display-success")
        let plan = makePlan(display: display, score: 0.9)
        let evaluation = makeEvaluation(score: 0.96)
        let callLog = CallLog()
        let sourceProvider = MockSourceProvider(
            images: [makeSourceImage(id: "background-1")],
            callLog: callLog
        )
        let aiProvider = MockAIProvider(
            words: [VocabularyItem.samples(count: 3)],
            analyses: [makeAnalysis()],
            evaluations: [evaluation],
            callLog: callLog
        )
        let layoutPlanner = MockLayoutPlanner(layoutBatches: [[plan]], callLog: callLog)
        let renderEngine = MockRenderEngine(callLog: callLog)
        let desktopSetter = MockDesktopWallpaperSetter(callLog: callLog)
        let historyStore = MockHistoryStore(callLog: callLog)
        let harness = WallpaperHarness(
            sourceProvider: sourceProvider,
            aiProvider: aiProvider,
            layoutPlanner: layoutPlanner,
            renderEngine: renderEngine,
            desktopSetter: desktopSetter,
            historyStore: historyStore,
            outputDirectory: outputDirectory,
            settings: .default
        )

        let result = try await harness.run(display: display)
        let record = result.record
        let finalURL = try XCTUnwrap(record.finalImageURL)

        XCTAssertEqual(result.state, .succeeded)
        XCTAssertNil(record.failureReason)
        XCTAssertEqual(record.display, display)
        XCTAssertEqual(record.words, VocabularyItem.samples(count: 3))
        XCTAssertEqual(record.layout, plan)
        XCTAssertEqual(record.evaluation, evaluation)
        XCTAssertEqual(record.providerID, sourceProvider.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: finalURL.path))
        XCTAssertEqual(desktopSetter.calls.map(\.fileURL), [finalURL])
        XCTAssertEqual(desktopSetter.calls.map(\.display), [display])
        XCTAssertEqual(historyStore.appendedRecords, [record])
        XCTAssertEqual(
            callLog.events,
            ["source", "extractWords", "analyzeImage", "layout", "render", "evaluate", "setDesktop", "appendHistory"]
        )
    }

    func testLowScoreRetriesLayoutCandidatesBeforeRequestingNewBackground() async throws {
        let outputDirectory = try makeTemporaryDirectory()
        let display = makeDisplay(id: "display-layout-retry")
        let firstPlan = makePlan(display: display, score: 0.4, word: "meadow")
        let secondPlan = makePlan(display: display, score: 0.9, word: "ridge")
        let sourceProvider = MockSourceProvider(images: [makeSourceImage(id: "background-1")])
        let aiProvider = MockAIProvider(
            words: [VocabularyItem.samples(count: 3)],
            analyses: [makeAnalysis()],
            evaluations: [
                makeEvaluation(score: 0.2),
                makeEvaluation(score: 0.96)
            ]
        )
        let layoutPlanner = MockLayoutPlanner(layoutBatches: [[firstPlan, secondPlan]])
        let renderEngine = MockRenderEngine()
        let desktopSetter = MockDesktopWallpaperSetter()
        let historyStore = MockHistoryStore()
        let harness = WallpaperHarness(
            sourceProvider: sourceProvider,
            aiProvider: aiProvider,
            layoutPlanner: layoutPlanner,
            renderEngine: renderEngine,
            desktopSetter: desktopSetter,
            historyStore: historyStore,
            outputDirectory: outputDirectory,
            settings: .default
        )

        let result = try await harness.run(display: display)

        XCTAssertEqual(result.state, .succeeded)
        XCTAssertEqual(sourceProvider.makeSourceImageCalls.count, 1)
        XCTAssertEqual(renderEngine.renderedPlans, [firstPlan, secondPlan])
        XCTAssertEqual(aiProvider.evaluatedPlans, [firstPlan, secondPlan])
        XCTAssertEqual(desktopSetter.calls.count, 1)
        XCTAssertEqual(historyStore.appendedRecords.first?.layout, secondPlan)
    }

    func testExhaustedLayoutCandidatesRetryWithNewBackgroundUpToLimit() async throws {
        let outputDirectory = try makeTemporaryDirectory()
        let display = makeDisplay(id: "display-background-retry")
        let backgroundOnePlans = [
            makePlan(display: display, score: 0.2, word: "meadow"),
            makePlan(display: display, score: 0.3, word: "lantern")
        ]
        let backgroundTwoPlan = makePlan(display: display, score: 0.9, word: "harvest")
        let settings = AppSettings.default.withOverrides(
            maxBackgroundAttempts: 2,
            maxLayoutCandidates: 2
        )
        let sourceProvider = MockSourceProvider(
            images: [
                makeSourceImage(id: "background-1"),
                makeSourceImage(id: "background-2")
            ]
        )
        let aiProvider = MockAIProvider(
            words: [
                VocabularyItem.samples(count: 3),
                VocabularyItem.samples(count: 3)
            ],
            analyses: [makeAnalysis(), makeAnalysis()],
            evaluations: [
                makeEvaluation(score: 0.2),
                makeEvaluation(score: 0.3),
                makeEvaluation(score: 0.97)
            ]
        )
        let layoutPlanner = MockLayoutPlanner(
            layoutBatches: [backgroundOnePlans, [backgroundTwoPlan]]
        )
        let renderEngine = MockRenderEngine()
        let desktopSetter = MockDesktopWallpaperSetter()
        let historyStore = MockHistoryStore()
        let harness = WallpaperHarness(
            sourceProvider: sourceProvider,
            aiProvider: aiProvider,
            layoutPlanner: layoutPlanner,
            renderEngine: renderEngine,
            desktopSetter: desktopSetter,
            historyStore: historyStore,
            outputDirectory: outputDirectory,
            settings: settings
        )

        let result = try await harness.run(display: display)

        XCTAssertEqual(result.state, .succeeded)
        XCTAssertEqual(sourceProvider.makeSourceImageCalls.count, 2)
        XCTAssertEqual(aiProvider.extractWordsCalls.count, 2)
        XCTAssertEqual(aiProvider.analyzeImageCalls.count, 2)
        XCTAssertEqual(layoutPlanner.maxCandidatesRequests, [2, 2])
        XCTAssertEqual(
            renderEngine.renderedPlans,
            backgroundOnePlans + [backgroundTwoPlan]
        )
        XCTAssertEqual(historyStore.appendedRecords.first?.layout, backgroundTwoPlan)
    }

    func testMaxRetryExhaustionDoesNotSetDesktopAndRecordsFailure() async throws {
        let outputDirectory = try makeTemporaryDirectory()
        let display = makeDisplay(id: "display-exhausted")
        let settings = AppSettings.default.withOverrides(
            maxBackgroundAttempts: 2,
            maxLayoutCandidates: 2
        )
        let plans = [
            [makePlan(display: display, score: 0.2, word: "meadow")],
            [makePlan(display: display, score: 0.3, word: "ridge")]
        ]
        let lastEvaluation = makeEvaluation(score: 0.3)
        let sourceProvider = MockSourceProvider(
            images: [
                makeSourceImage(id: "background-1"),
                makeSourceImage(id: "background-2")
            ]
        )
        let aiProvider = MockAIProvider(
            words: [
                VocabularyItem.samples(count: 3),
                VocabularyItem.samples(count: 3)
            ],
            analyses: [makeAnalysis(), makeAnalysis()],
            evaluations: [
                makeEvaluation(score: 0.2),
                lastEvaluation
            ]
        )
        let layoutPlanner = MockLayoutPlanner(layoutBatches: plans)
        let renderEngine = MockRenderEngine()
        let desktopSetter = MockDesktopWallpaperSetter()
        let historyStore = MockHistoryStore()
        let harness = WallpaperHarness(
            sourceProvider: sourceProvider,
            aiProvider: aiProvider,
            layoutPlanner: layoutPlanner,
            renderEngine: renderEngine,
            desktopSetter: desktopSetter,
            historyStore: historyStore,
            outputDirectory: outputDirectory,
            settings: settings
        )

        let result = try await harness.run(display: display)
        let failureReason = try XCTUnwrap(result.record.failureReason)

        XCTAssertEqual(result.state, .failed)
        XCTAssertEqual(sourceProvider.makeSourceImageCalls.count, 2)
        XCTAssertTrue(desktopSetter.calls.isEmpty)
        XCTAssertEqual(historyStore.appendedRecords.count, 1)
        XCTAssertEqual(historyStore.appendedRecords.first, result.record)
        XCTAssertNil(result.record.finalImageURL)
        XCTAssertEqual(result.record.evaluation, lastEvaluation)
        XCTAssertTrue(failureReason.contains("No layout candidate passed"))
        XCTAssertTrue(failureReason.contains("2 background attempt"))
    }

    func testOneDisplayFailureDoesNotCorruptAnotherRun() async throws {
        let failingDisplay = makeDisplay(id: "display-failing")
        let succeedingDisplay = makeDisplay(id: "display-succeeding")
        let failingHarnessOutput = try makeTemporaryDirectory()
        let succeedingHarnessOutput = try makeTemporaryDirectory()
        let failingSetter = MockDesktopWallpaperSetter()
        let failingHistory = MockHistoryStore()
        let succeedingSetter = MockDesktopWallpaperSetter()
        let succeedingHistory = MockHistoryStore()
        let failingHarness = WallpaperHarness(
            sourceProvider: MockSourceProvider(images: [makeSourceImage(id: "bad-background")]),
            aiProvider: MockAIProvider(
                words: [VocabularyItem.samples(count: 3)],
                analyses: [makeAnalysis()],
                evaluations: [makeEvaluation(score: 0.2)]
            ),
            layoutPlanner: MockLayoutPlanner(
                layoutBatches: [[makePlan(display: failingDisplay, score: 0.2)]]
            ),
            renderEngine: MockRenderEngine(),
            desktopSetter: failingSetter,
            historyStore: failingHistory,
            outputDirectory: failingHarnessOutput,
            settings: AppSettings.default.withOverrides(
                maxBackgroundAttempts: 1,
                maxLayoutCandidates: 1
            )
        )
        let succeedingPlan = makePlan(display: succeedingDisplay, score: 0.9)
        let succeedingHarness = WallpaperHarness(
            sourceProvider: MockSourceProvider(images: [makeSourceImage(id: "good-background")]),
            aiProvider: MockAIProvider(
                words: [VocabularyItem.samples(count: 3)],
                analyses: [makeAnalysis()],
                evaluations: [makeEvaluation(score: 0.97)]
            ),
            layoutPlanner: MockLayoutPlanner(layoutBatches: [[succeedingPlan]]),
            renderEngine: MockRenderEngine(),
            desktopSetter: succeedingSetter,
            historyStore: succeedingHistory,
            outputDirectory: succeedingHarnessOutput,
            settings: AppSettings.default.withOverrides(
                maxBackgroundAttempts: 1,
                maxLayoutCandidates: 1
            )
        )

        let failed = try await failingHarness.run(display: failingDisplay)
        let succeeded = try await succeedingHarness.run(display: succeedingDisplay)

        XCTAssertEqual(failed.state, .failed)
        XCTAssertEqual(succeeded.state, .succeeded)
        XCTAssertTrue(failingSetter.calls.isEmpty)
        XCTAssertEqual(succeedingSetter.calls.count, 1)
        XCTAssertEqual(failingHistory.appendedRecords.first?.display.id, failingDisplay.id)
        XCTAssertEqual(succeedingHistory.appendedRecords.first?.display.id, succeedingDisplay.id)
    }

    func testCancellationReturnsCancelledWithoutSettingDesktopOrRecordingHistory() async throws {
        let outputDirectory = try makeTemporaryDirectory()
        let display = makeDisplay(id: "display-cancelled")
        let desktopSetter = MockDesktopWallpaperSetter()
        let historyStore = MockHistoryStore()
        let harness = WallpaperHarness(
            sourceProvider: ThrowingSourceProvider(error: CancellationError()),
            aiProvider: MockAIProvider(words: [], analyses: [], evaluations: []),
            layoutPlanner: MockLayoutPlanner(layoutBatches: []),
            renderEngine: MockRenderEngine(),
            desktopSetter: desktopSetter,
            historyStore: historyStore,
            outputDirectory: outputDirectory,
            settings: .default
        )

        let result = try await harness.run(display: display)

        XCTAssertEqual(result.state, .cancelled)
        XCTAssertEqual(result.record.display, display)
        XCTAssertTrue(desktopSetter.calls.isEmpty)
        XCTAssertTrue(historyStore.appendedRecords.isEmpty)
        XCTAssertNil(result.record.finalImageURL)
        XCTAssertNil(result.record.failureReason)
    }

    func testURLSessionCancelledErrorReturnsCancelledWithoutRecordingHistory() async throws {
        let outputDirectory = try makeTemporaryDirectory()
        let display = makeDisplay(id: "display-url-cancelled")
        let desktopSetter = MockDesktopWallpaperSetter()
        let historyStore = MockHistoryStore()
        let harness = WallpaperHarness(
            sourceProvider: ThrowingSourceProvider(error: URLError(.cancelled)),
            aiProvider: MockAIProvider(words: [], analyses: [], evaluations: []),
            layoutPlanner: MockLayoutPlanner(layoutBatches: []),
            renderEngine: MockRenderEngine(),
            desktopSetter: desktopSetter,
            historyStore: historyStore,
            outputDirectory: outputDirectory,
            settings: .default
        )

        let result = try await harness.run(display: display)

        XCTAssertEqual(result.state, .cancelled)
        XCTAssertEqual(result.record.display, display)
        XCTAssertTrue(desktopSetter.calls.isEmpty)
        XCTAssertTrue(historyStore.appendedRecords.isEmpty)
        XCTAssertNil(result.record.failureReason)
    }

    func testCancelledTaskWithNonCancellationErrorRecordsFailure() async throws {
        let outputDirectory = try makeTemporaryDirectory()
        let display = makeDisplay(id: "display-cancelled-real-error")
        let sourceProvider = SuspendedThrowingSourceProvider(error: MockError.unexpectedCall)
        let historyStore = MockHistoryStore()
        let harness = WallpaperHarness(
            sourceProvider: sourceProvider,
            aiProvider: MockAIProvider(words: [], analyses: [], evaluations: []),
            layoutPlanner: MockLayoutPlanner(layoutBatches: []),
            renderEngine: MockRenderEngine(),
            desktopSetter: MockDesktopWallpaperSetter(),
            historyStore: historyStore,
            outputDirectory: outputDirectory,
            settings: .default
        )

        let task = Task {
            try await harness.run(display: display)
        }
        await sourceProvider.waitUntilStarted()
        task.cancel()
        sourceProvider.release()

        let result = try await task.value
        let failureReason = try XCTUnwrap(result.record.failureReason)

        XCTAssertEqual(result.state, .failed)
        XCTAssertEqual(historyStore.appendedRecords, [result.record])
        XCTAssertEqual(result.record.display, display)
        XCTAssertTrue(failureReason.contains("MockError"))
    }

    func testBackgroundRetryFailureDoesNotLeakPreviousAttemptLayoutOrEvaluation() async throws {
        let outputDirectory = try makeTemporaryDirectory()
        let display = makeDisplay(id: "display-context-reset")
        let firstPlan = makePlan(display: display, score: 0.2, word: "meadow")
        let firstWords = makeVocabularyItems(prefix: "first", count: 3)
        let secondWords = makeVocabularyItems(prefix: "second", count: 3)
        let historyStore = MockHistoryStore()
        let harness = WallpaperHarness(
            sourceProvider: MockSourceProvider(
                images: [
                    makeSourceImage(id: "background-1"),
                    makeSourceImage(id: "background-2")
                ]
            ),
            aiProvider: MockAIProvider(
                words: [firstWords, secondWords],
                analyses: [makeAnalysis(), makeAnalysis()],
                evaluations: [makeEvaluation(score: 0.2)]
            ),
            layoutPlanner: MockLayoutPlanner(layoutBatches: [[firstPlan], []]),
            renderEngine: MockRenderEngine(),
            desktopSetter: MockDesktopWallpaperSetter(),
            historyStore: historyStore,
            outputDirectory: outputDirectory,
            settings: AppSettings.default.withOverrides(
                maxBackgroundAttempts: 2,
                maxLayoutCandidates: 1
            )
        )

        let result = try await harness.run(display: display)
        let failureReason = try XCTUnwrap(result.record.failureReason)

        XCTAssertEqual(result.state, .failed)
        XCTAssertEqual(result.record.words, secondWords)
        XCTAssertNil(result.record.layout)
        XCTAssertNil(result.record.evaluation)
        XCTAssertTrue(failureReason.contains("No layout candidates"))
        XCTAssertEqual(historyStore.appendedRecords, [result.record])
    }

    func testSecondLayoutCandidateRenderFailureDoesNotKeepPreviousEvaluation() async throws {
        let outputDirectory = try makeTemporaryDirectory()
        let display = makeDisplay(id: "display-stale-evaluation")
        let firstPlan = makePlan(display: display, score: 0.2, word: "meadow")
        let secondPlan = makePlan(display: display, score: 0.9, word: "ridge")
        let firstEvaluation = makeEvaluation(score: 0.2)
        let historyStore = MockHistoryStore()
        let renderEngine = FailingRenderEngine(failingCall: 2, error: MockError.unexpectedCall)
        let harness = WallpaperHarness(
            sourceProvider: MockSourceProvider(images: [makeSourceImage(id: "background-1")]),
            aiProvider: MockAIProvider(
                words: [VocabularyItem.samples(count: 3)],
                analyses: [makeAnalysis()],
                evaluations: [firstEvaluation]
            ),
            layoutPlanner: MockLayoutPlanner(layoutBatches: [[firstPlan, secondPlan]]),
            renderEngine: renderEngine,
            desktopSetter: MockDesktopWallpaperSetter(),
            historyStore: historyStore,
            outputDirectory: outputDirectory,
            settings: AppSettings.default.withOverrides(
                maxBackgroundAttempts: 1,
                maxLayoutCandidates: 2
            )
        )

        let result = try await harness.run(display: display)

        XCTAssertEqual(result.state, .failed)
        XCTAssertEqual(renderEngine.renderedPlans, [firstPlan, secondPlan])
        XCTAssertEqual(result.record.layout, secondPlan)
        XCTAssertNil(result.record.evaluation)
        XCTAssertEqual(historyStore.appendedRecords, [result.record])
    }

    func testInvalidProviderWordCountFailsWithoutRenderingOrSettingDesktop() async throws {
        let outputDirectory = try makeTemporaryDirectory()
        let display = makeDisplay(id: "display-invalid-words")
        let renderEngine = MockRenderEngine()
        let desktopSetter = MockDesktopWallpaperSetter()
        let historyStore = MockHistoryStore()
        let harness = WallpaperHarness(
            sourceProvider: MockSourceProvider(images: [makeSourceImage(id: "background-1")]),
            aiProvider: MockAIProvider(
                words: [makeVocabularyItems(prefix: "short", count: 2)],
                analyses: [],
                evaluations: []
            ),
            layoutPlanner: MockLayoutPlanner(layoutBatches: []),
            renderEngine: renderEngine,
            desktopSetter: desktopSetter,
            historyStore: historyStore,
            outputDirectory: outputDirectory,
            settings: AppSettings.default.withOverrides(
                maxBackgroundAttempts: 1,
                maxLayoutCandidates: 1
            )
        )

        let result = try await harness.run(display: display)
        let failureReason = try XCTUnwrap(result.record.failureReason)

        XCTAssertEqual(result.state, .failed)
        XCTAssertTrue(result.record.words.isEmpty)
        XCTAssertNil(result.record.layout)
        XCTAssertNil(result.record.evaluation)
        XCTAssertTrue(renderEngine.renderedPlans.isEmpty)
        XCTAssertTrue(desktopSetter.calls.isEmpty)
        XCTAssertEqual(historyStore.appendedRecords, [result.record])
        XCTAssertTrue(failureReason.contains("word count"))
        XCTAssertTrue(failureReason.contains("3...5"))
    }

    func testInvalidProviderWordCountRetriesWithNextBackground() async throws {
        let outputDirectory = try makeTemporaryDirectory()
        let display = makeDisplay(id: "display-invalid-words-retry")
        let validWords = makeVocabularyItems(prefix: "valid", count: 3)
        let secondPlan = makePlan(display: display, score: 0.9, word: "valid")
        let sourceProvider = MockSourceProvider(
            images: [
                makeSourceImage(id: "background-invalid"),
                makeSourceImage(id: "background-valid")
            ]
        )
        let aiProvider = MockAIProvider(
            words: [
                makeVocabularyItems(prefix: "short", count: 2),
                validWords
            ],
            analyses: [makeAnalysis()],
            evaluations: [makeEvaluation(score: 0.97)]
        )
        let renderEngine = MockRenderEngine()
        let desktopSetter = MockDesktopWallpaperSetter()
        let historyStore = MockHistoryStore()
        let harness = WallpaperHarness(
            sourceProvider: sourceProvider,
            aiProvider: aiProvider,
            layoutPlanner: MockLayoutPlanner(layoutBatches: [[secondPlan]]),
            renderEngine: renderEngine,
            desktopSetter: desktopSetter,
            historyStore: historyStore,
            outputDirectory: outputDirectory,
            settings: AppSettings.default.withOverrides(
                maxBackgroundAttempts: 2,
                maxLayoutCandidates: 1
            )
        )

        let result = try await harness.run(display: display)

        XCTAssertEqual(result.state, .succeeded)
        XCTAssertEqual(sourceProvider.makeSourceImageCalls.count, 2)
        XCTAssertEqual(aiProvider.analyzeImageCalls.count, 1)
        XCTAssertEqual(renderEngine.renderedPlans, [secondPlan])
        XCTAssertEqual(desktopSetter.calls.count, 1)
        XCTAssertEqual(historyStore.appendedRecords, [result.record])
        XCTAssertEqual(result.record.words, validWords)
    }

    func testFailureReasonIdentifiesTextCorrectnessGateFailure() async throws {
        let outputDirectory = try makeTemporaryDirectory()
        let display = makeDisplay(id: "display-text-correctness")
        let harness = WallpaperHarness(
            sourceProvider: MockSourceProvider(images: [makeSourceImage(id: "background-1")]),
            aiProvider: MockAIProvider(
                words: [VocabularyItem.samples(count: 3)],
                analyses: [makeAnalysis()],
                evaluations: [
                    makeEvaluation(score: 0.98, textCorrectness: 0.7)
                ]
            ),
            layoutPlanner: MockLayoutPlanner(
                layoutBatches: [[makePlan(display: display, score: 0.9)]]
            ),
            renderEngine: MockRenderEngine(),
            desktopSetter: MockDesktopWallpaperSetter(),
            historyStore: MockHistoryStore(),
            outputDirectory: outputDirectory,
            settings: AppSettings.default.withOverrides(
                maxBackgroundAttempts: 1,
                maxLayoutCandidates: 1
            )
        )

        let result = try await harness.run(display: display)
        let failureReason = try XCTUnwrap(result.record.failureReason)

        XCTAssertEqual(result.state, .failed)
        XCTAssertTrue(failureReason.contains("text correctness"))
    }

    func testStateMachineOnlyAllowsValidOrderedTransitions() throws {
        var machine = WallpaperJobStateMachine()

        XCTAssertEqual(machine.stage, .pending)
        XCTAssertThrowsError(try machine.apply(.rendered)) { error in
            XCTAssertEqual(error as? WallpaperJobError, .invalidTransition)
        }

        try machine.apply(.start)
        try machine.apply(.sourceReady)
        try machine.apply(.wordsExtracted)
        try machine.apply(.analysisReady)
        try machine.apply(.layoutSelected)
        try machine.apply(.rendered)
        try machine.apply(.evaluationAccepted)
        try machine.apply(.wallpaperSet)
        try machine.apply(.historyRecorded)

        XCTAssertEqual(machine.stage, .succeeded)
        XCTAssertThrowsError(try machine.apply(.fail)) { error in
            XCTAssertEqual(error as? WallpaperJobError, .invalidTransition)
        }
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WallpaperHarnessTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }

    private func makeDisplay(id: String) -> DisplayTarget {
        DisplayTarget(
            id: id,
            frame: CoreRect(x: 0, y: 0, width: 1440, height: 900),
            pixelSize: PixelSize(width: 1440, height: 900),
            scale: 2,
            colorSpace: "Display P3",
            isMain: true,
            friendlyName: id
        )
    }

    private func makeSourceImage(id: String) -> SourceImage {
        SourceImage(
            imageData: Data(id.utf8),
            attribution: .aiGenerated(
                AIGeneratedAttribution(
                    prompt: "A quiet rural wallpaper",
                    providerID: "mock-source",
                    model: "mock-image"
                )
            )
        )
    }

    private func makeAnalysis() -> ImageAnalysis {
        ImageAnalysis(
            summary: "A calm rural scene.",
            safeTextRegions: [CoreRect(x: 120, y: 180, width: 900, height: 260)],
            maskConfidence: 0.9
        )
    }

    private func makePlan(
        display: DisplayTarget,
        score: Double,
        word: String = "meadow"
    ) -> LayoutPlan {
        LayoutPlan(
            displayID: display.id,
            wordPlacements: [
                LayoutWordPlacement(
                    word: word,
                    rect: CoreRect(x: 160, y: 240, width: 360, height: 120),
                    baseline: CorePoint(x: 160, y: 320),
                    fontSize: 72,
                    depth: 0.2,
                    opacity: 0.95
                )
            ],
            depthMode: .depthAware,
            score: score
        )
    }

    private func makeEvaluation(
        score: Double,
        noBadOcclusion: Double? = nil,
        textCorrectness: Double? = nil
    ) -> EvaluationResult {
        EvaluationResult(
            readability: score,
            sceneFit: score,
            depthBelievability: score,
            desktopCalmness: score,
            wordRelevance: score,
            noBadOcclusion: noBadOcclusion ?? score,
            textCorrectness: textCorrectness ?? score,
            notes: "score \(score)"
        )
    }

    private func makeVocabularyItems(prefix: String, count: Int) -> [VocabularyItem] {
        (1...count).map { index in
            VocabularyItem(
                word: "\(prefix)-\(index)",
                partOfSpeech: "noun",
                zhDefinition: "测试词",
                example: "The \(prefix) word appears in a test scene.",
                difficulty: 2,
                sourceReason: "Harness test fixture."
            )
        }
    }
}

private final class CallLog: @unchecked Sendable {
    private(set) var events: [String] = []

    func append(_ event: String) {
        events.append(event)
    }
}

private final class MockSourceProvider: SourceProvider, @unchecked Sendable {
    let id = "mock-source"
    private(set) var makeSourceImageCalls: [DisplayTarget] = []
    private var images: [SourceImage]
    private let callLog: CallLog?

    init(images: [SourceImage], callLog: CallLog? = nil) {
        self.images = images
        self.callLog = callLog
    }

    func makeSourceImage(for display: DisplayTarget, settings: AppSettings) async throws -> SourceImage {
        callLog?.append("source")
        makeSourceImageCalls.append(display)

        guard !images.isEmpty else {
            throw MockError.unexpectedCall
        }

        return images.removeFirst()
    }
}

private final class MockAIProvider: AIProvider, @unchecked Sendable {
    private(set) var extractWordsCalls: [Data] = []
    private(set) var analyzeImageCalls: [DisplayTarget] = []
    private(set) var evaluatedPlans: [LayoutPlan] = []
    private var words: [[VocabularyItem]]
    private var analyses: [ImageAnalysis]
    private var evaluations: [EvaluationResult]
    private let callLog: CallLog?

    init(
        words: [[VocabularyItem]],
        analyses: [ImageAnalysis],
        evaluations: [EvaluationResult],
        callLog: CallLog? = nil
    ) {
        self.words = words
        self.analyses = analyses
        self.evaluations = evaluations
        self.callLog = callLog
    }

    func generateImage(prompt: String, size: CGSize) async throws -> GeneratedSourceImage {
        throw MockError.unexpectedCall
    }

    func extractWords(from image: Data, countRange: ClosedRange<Int>) async throws -> [VocabularyItem] {
        callLog?.append("extractWords")
        extractWordsCalls.append(image)
        XCTAssertEqual(countRange, 3...5)

        guard !words.isEmpty else {
            throw MockError.unexpectedCall
        }

        return words.removeFirst()
    }

    func analyzeImage(_ image: Data, display: DisplayTarget) async throws -> ImageAnalysis {
        callLog?.append("analyzeImage")
        analyzeImageCalls.append(display)

        guard !analyses.isEmpty else {
            throw MockError.unexpectedCall
        }

        return analyses.removeFirst()
    }

    func evaluate(
        renderedImage: Data,
        plan: LayoutPlan,
        words: [VocabularyItem]
    ) async throws -> EvaluationResult {
        callLog?.append("evaluate")
        evaluatedPlans.append(plan)

        guard !evaluations.isEmpty else {
            throw MockError.unexpectedCall
        }

        return evaluations.removeFirst()
    }
}

private final class MockLayoutPlanner: LayoutPlanner, @unchecked Sendable {
    private(set) var maxCandidatesRequests: [Int] = []
    private var layoutBatches: [[LayoutPlan]]
    private let callLog: CallLog?

    init(layoutBatches: [[LayoutPlan]], callLog: CallLog? = nil) {
        self.layoutBatches = layoutBatches
        self.callLog = callLog
    }

    func makeLayoutCandidates(
        display: DisplayTarget,
        analysis: ImageAnalysis,
        words: [VocabularyItem],
        maxCandidates: Int
    ) -> [LayoutPlan] {
        callLog?.append("layout")
        maxCandidatesRequests.append(maxCandidates)

        guard !layoutBatches.isEmpty else {
            return []
        }

        return layoutBatches.removeFirst()
    }
}

private final class MockRenderEngine: RenderEngine, @unchecked Sendable {
    private(set) var renderedPlans: [LayoutPlan] = []
    private let callLog: CallLog?

    init(callLog: CallLog? = nil) {
        self.callLog = callLog
    }

    func render(
        background: Data,
        plan: LayoutPlan,
        display: DisplayTarget
    ) throws -> RenderedWallpaper {
        callLog?.append("render")
        renderedPlans.append(plan)

        return RenderedWallpaper(
            pngData: Data("render-\(renderedPlans.count)".utf8),
            displayID: display.id,
            layoutPlan: plan,
            pixelSize: display.pixelSize
        )
    }
}

private final class FailingRenderEngine: RenderEngine, @unchecked Sendable {
    private(set) var renderedPlans: [LayoutPlan] = []
    private let failingCall: Int
    private let error: Error

    init(failingCall: Int, error: Error) {
        self.failingCall = failingCall
        self.error = error
    }

    func render(
        background: Data,
        plan: LayoutPlan,
        display: DisplayTarget
    ) throws -> RenderedWallpaper {
        renderedPlans.append(plan)

        if renderedPlans.count == failingCall {
            throw error
        }

        return RenderedWallpaper(
            pngData: Data("render-\(renderedPlans.count)".utf8),
            displayID: display.id,
            layoutPlan: plan,
            pixelSize: display.pixelSize
        )
    }
}

private final class MockDesktopWallpaperSetter: DesktopWallpaperSetter, @unchecked Sendable {
    private(set) var calls: [(fileURL: URL, display: DisplayTarget)] = []
    private let callLog: CallLog?

    init(callLog: CallLog? = nil) {
        self.callLog = callLog
    }

    func setWallpaper(fileURL: URL, for display: DisplayTarget) throws {
        callLog?.append("setDesktop")
        calls.append((fileURL, display))
    }
}

private final class MockHistoryStore: HistoryStore, @unchecked Sendable {
    private(set) var appendedRecords: [GeneratedWallpaper] = []
    private let callLog: CallLog?

    init(callLog: CallLog? = nil) {
        self.callLog = callLog
    }

    func append(_ record: GeneratedWallpaper) throws {
        callLog?.append("appendHistory")
        appendedRecords.append(record)
    }

    func recent(displayID: String, limit: Int) throws -> [GeneratedWallpaper] {
        Array(appendedRecords.filter { $0.display.id == displayID }.suffix(limit))
    }
}

private enum MockError: Error {
    case unexpectedCall
}

private struct ThrowingSourceProvider: SourceProvider {
    let id = "throwing-source"
    var error: Error

    func makeSourceImage(for display: DisplayTarget, settings: AppSettings) async throws -> SourceImage {
        throw error
    }
}

private final class SuspendedThrowingSourceProvider: SourceProvider, @unchecked Sendable {
    let id = "suspended-throwing-source"
    private let error: Error
    private let lock = NSLock()
    private var didStart = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    init(error: Error) {
        self.error = error
    }

    func makeSourceImage(for display: DisplayTarget, settings: AppSettings) async throws -> SourceImage {
        markStarted()

        await withCheckedContinuation { continuation in
            lock.lock()
            releaseContinuation = continuation
            lock.unlock()
        }

        throw error
    }

    func waitUntilStarted() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if didStart {
                lock.unlock()
                continuation.resume()
            } else {
                startWaiters.append(continuation)
                lock.unlock()
            }
        }
    }

    func release() {
        lock.lock()
        let continuation = releaseContinuation
        releaseContinuation = nil
        lock.unlock()

        continuation?.resume()
    }

    private func markStarted() {
        lock.lock()
        didStart = true
        let waiters = startWaiters
        startWaiters.removeAll()
        lock.unlock()

        for waiter in waiters {
            waiter.resume()
        }
    }
}

private extension AppSettings {
    func withOverrides(
        maxBackgroundAttempts: Int? = nil,
        maxLayoutCandidates: Int? = nil,
        minimumScore: Double? = nil
    ) -> AppSettings {
        AppSettings(
            autoUpdateEnabled: autoUpdateEnabled,
            refreshIntervalHours: refreshIntervalHours,
            maxBackgroundAttempts: maxBackgroundAttempts ?? self.maxBackgroundAttempts,
            maxLayoutCandidates: maxLayoutCandidates ?? self.maxLayoutCandidates,
            minimumScore: minimumScore ?? self.minimumScore,
            historyLimitPerDisplay: historyLimitPerDisplay,
            preferredThemes: preferredThemes,
            enabledDisplayIDs: enabledDisplayIDs
        )
    }
}
