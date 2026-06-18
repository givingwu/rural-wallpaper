import Foundation
import XCTest
@testable import RuralWallpaperCore

final class DisplayCoordinatorTests: XCTestCase {
    func testRunOnceStartsIndependentRunForEachCurrentDisplayWhenNoDisplayFilterExists() async throws {
        let displays = [makeDisplay(id: "left"), makeDisplay(id: "right")]
        let provider = StubDisplayProvider(displays: displays)
        let runner = RecordingDisplayRunner(delayNanoseconds: 20_000_000)
        let coordinator = DisplayCoordinator(displayProvider: provider, runner: runner)

        let results = await coordinator.runOnce(settings: .default)
        let startedDisplayIDs = await runner.startedDisplayIDs()
        let maxConcurrentRuns = await runner.maxConcurrentRuns()

        XCTAssertEqual(Set(results.map(\.display.id)), ["left", "right"])
        XCTAssertEqual(Set(startedDisplayIDs), ["left", "right"])
        XCTAssertEqual(maxConcurrentRuns, 2)
        XCTAssertEqual(Set(results.map(\.state)), Set<WallpaperJobState>([.succeeded]))
    }

    func testRunOnceSkipsDisplaysNotEnabledInSettings() async throws {
        let enabled = makeDisplay(id: "enabled")
        let disabled = makeDisplay(id: "disabled")
        let provider = StubDisplayProvider(displays: [enabled, disabled])
        let runner = RecordingDisplayRunner()
        let coordinator = DisplayCoordinator(displayProvider: provider, runner: runner)
        let settings = AppSettings.default.withEnabledDisplayIDs(["enabled"])

        let results = await coordinator.runOnce(settings: settings)
        let startedDisplayIDs = await runner.startedDisplayIDs()

        XCTAssertEqual(results.map(\.display.id), ["enabled"])
        XCTAssertEqual(startedDisplayIDs, ["enabled"])
    }

    func testRunOnceRecordsDisplayFailureWithoutPreventingOtherDisplaySuccess() async throws {
        let failing = makeDisplay(id: "failing")
        let succeeding = makeDisplay(id: "succeeding")
        let provider = StubDisplayProvider(displays: [failing, succeeding])
        let runner = RecordingDisplayRunner(failingDisplayIDs: ["failing"])
        let coordinator = DisplayCoordinator(displayProvider: provider, runner: runner)

        let results = await coordinator.runOnce(settings: .default)
        let startedDisplayIDs = await runner.startedDisplayIDs()
        let byDisplayID = Dictionary(uniqueKeysWithValues: results.map { ($0.display.id, $0) })

        XCTAssertEqual(Set(startedDisplayIDs), ["failing", "succeeding"])
        XCTAssertEqual(byDisplayID["failing"]?.state, .failed)
        XCTAssertTrue(byDisplayID["failing"]?.errorDescription?.contains("planned failure") == true)
        XCTAssertEqual(byDisplayID["succeeding"]?.state, .succeeded)
        XCTAssertNil(byDisplayID["succeeding"]?.errorDescription)
    }

    func testRefreshDisplaysCancelsRunForDisappearedDisplay() async throws {
        let first = makeDisplay(id: "first")
        let second = makeDisplay(id: "second")
        let provider = StubDisplayProvider(displays: [first])
        let runner = RecordingDisplayRunner(suspendUntilCancelledDisplayIDs: ["first", "second"])
        let coordinator = DisplayCoordinator(displayProvider: provider, runner: runner)

        await coordinator.refreshDisplays(settings: .default)
        await runner.waitUntilStarted(count: 1)

        provider.setDisplays([second])
        await coordinator.refreshDisplays(settings: .default)

        await runner.waitUntilCancelled(displayID: "first")
        await runner.waitUntilStarted(count: 2)
        await coordinator.cancelAllRunningTasks()
        await runner.waitUntilCancelled(displayID: "second")
        let cancelledDisplayIDs = await runner.cancelledDisplayIDs()

        XCTAssertEqual(Set(cancelledDisplayIDs), ["first", "second"])
    }

    func testRunOnceDoesNotStartDuplicateConcurrentRunForSameDisplay() async throws {
        let display = makeDisplay(id: "only")
        let provider = StubDisplayProvider(displays: [display])
        let runner = RecordingDisplayRunner(delayNanoseconds: 80_000_000)
        let coordinator = DisplayCoordinator(displayProvider: provider, runner: runner)

        let first = Task {
            await coordinator.runOnce(settings: .default)
        }
        await runner.waitUntilStarted(count: 1)

        let second = Task {
            await coordinator.runOnce(settings: .default)
        }

        _ = await first.value
        _ = await second.value
        let startedDisplayIDs = await runner.startedDisplayIDs()

        XCTAssertEqual(startedDisplayIDs, ["only"])
    }

    private func makeDisplay(id: String) -> DisplayTarget {
        DisplayTarget(
            id: id,
            frame: CoreRect(x: 0, y: 0, width: 1440, height: 900),
            pixelSize: PixelSize(width: 1440, height: 900),
            scale: 2,
            colorSpace: "Display P3",
            isMain: id == "left" || id == "enabled",
            friendlyName: id
        )
    }
}

private final class StubDisplayProvider: DisplayProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var displays: [DisplayTarget]

    init(displays: [DisplayTarget]) {
        self.displays = displays
    }

    func currentDisplays() -> [DisplayTarget] {
        lock.lock()
        defer { lock.unlock() }
        return displays
    }

    func setDisplays(_ displays: [DisplayTarget]) {
        lock.lock()
        self.displays = displays
        lock.unlock()
    }
}

private actor RecordingDisplayRunner: DisplayWallpaperRunner {
    private let failingDisplayIDs: Set<String>
    private let suspendUntilCancelledDisplayIDs: Set<String>
    private let delayNanoseconds: UInt64
    private var started: [String] = []
    private var cancelled: [String] = []
    private var activeRunCount = 0
    private var peakActiveRunCount = 0
    private var startWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var cancellationWaiters: [
        String: [CheckedContinuation<Void, Never>]
    ] = [:]

    init(
        failingDisplayIDs: Set<String> = [],
        suspendUntilCancelledDisplayIDs: Set<String> = [],
        delayNanoseconds: UInt64 = 0
    ) {
        self.failingDisplayIDs = failingDisplayIDs
        self.suspendUntilCancelledDisplayIDs = suspendUntilCancelledDisplayIDs
        self.delayNanoseconds = delayNanoseconds
    }

    func run(display: DisplayTarget) async throws -> WallpaperHarnessResult {
        started.append(display.id)
        activeRunCount += 1
        peakActiveRunCount = max(peakActiveRunCount, activeRunCount)
        resumeSatisfiedStartWaiters()
        defer { activeRunCount -= 1 }

        if failingDisplayIDs.contains(display.id) {
            throw RunnerError.plannedFailure(displayID: display.id)
        }

        if suspendUntilCancelledDisplayIDs.contains(display.id) {
            do {
                while true {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
            } catch is CancellationError {
                cancelled.append(display.id)
                resumeCancellationWaiters(for: display.id)
                throw CancellationError()
            }
        }

        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }

        return makeHarnessResult(display: display, state: .succeeded)
    }

    func waitUntilStarted(count: Int) async {
        if started.count >= count {
            return
        }

        await withCheckedContinuation { continuation in
            startWaiters.append((count: count, continuation: continuation))
        }
    }

    func waitUntilCancelled(displayID: String) async {
        if cancelled.contains(displayID) {
            return
        }

        await withCheckedContinuation { continuation in
            cancellationWaiters[displayID, default: []].append(continuation)
        }
    }

    func startedDisplayIDs() -> [String] {
        started
    }

    func cancelledDisplayIDs() -> [String] {
        cancelled
    }

    func maxConcurrentRuns() -> Int {
        peakActiveRunCount
    }

    private func makeHarnessResult(
        display: DisplayTarget,
        state: WallpaperJobState
    ) -> WallpaperHarnessResult {
        WallpaperHarnessResult(
            state: state,
            record: GeneratedWallpaper(
                id: "record-\(display.id)",
                finalImageURL: nil,
                sourceImageURL: nil,
                display: display,
                words: [],
                layout: nil,
                evaluation: nil,
                attribution: nil,
                providerID: "test-runner"
            )
        )
    }

    private func resumeSatisfiedStartWaiters() {
        let ready = startWaiters.filter { started.count >= $0.count }
        startWaiters.removeAll { started.count >= $0.count }
        ready.forEach { $0.continuation.resume() }
    }

    private func resumeCancellationWaiters(for displayID: String) {
        let waiters = cancellationWaiters.removeValue(forKey: displayID) ?? []
        waiters.forEach { $0.resume() }
    }
}

private enum RunnerError: Error, LocalizedError {
    case plannedFailure(displayID: String)

    var errorDescription: String? {
        switch self {
        case .plannedFailure(let displayID):
            return "planned failure for \(displayID)"
        }
    }
}

private extension AppSettings {
    func withEnabledDisplayIDs(_ enabledDisplayIDs: Set<String>) -> AppSettings {
        AppSettings(
            autoUpdateEnabled: autoUpdateEnabled,
            refreshIntervalHours: refreshIntervalHours,
            maxBackgroundAttempts: maxBackgroundAttempts,
            maxLayoutCandidates: maxLayoutCandidates,
            minimumScore: minimumScore,
            historyLimitPerDisplay: historyLimitPerDisplay,
            preferredThemes: preferredThemes,
            enabledDisplayIDs: enabledDisplayIDs
        )
    }
}
