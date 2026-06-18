import Foundation

public protocol DisplayWallpaperRunner: Sendable {
    func run(display: DisplayTarget) async throws -> WallpaperHarnessResult
}

public struct WallpaperHarnessDisplayRunner: DisplayWallpaperRunner {
    private let harness: WallpaperHarness

    public init(harness: WallpaperHarness) {
        self.harness = harness
    }

    public func run(display: DisplayTarget) async throws -> WallpaperHarnessResult {
        try await harness.run(display: display)
    }
}

public struct DisplayRunResult: Equatable, Sendable {
    public var display: DisplayTarget
    public var state: WallpaperJobState
    public var harnessResult: WallpaperHarnessResult?
    public var errorDescription: String?

    public init(
        display: DisplayTarget,
        state: WallpaperJobState,
        harnessResult: WallpaperHarnessResult?,
        errorDescription: String?
    ) {
        self.display = display
        self.state = state
        self.harnessResult = harnessResult
        self.errorDescription = errorDescription
    }
}

public actor DisplayCoordinator {
    private struct ActiveRun: Sendable {
        var token: UUID
        var signature: DisplaySignature
        var task: Task<DisplayRunResult, Never>
    }

    private struct DisplaySignature: Equatable, Sendable {
        var frame: CoreRect
        var pixelSize: PixelSize
        var scale: Double
        var colorSpace: String
        var isMain: Bool

        init(display: DisplayTarget) {
            self.frame = display.frame
            self.pixelSize = display.pixelSize
            self.scale = display.scale
            self.colorSpace = display.colorSpace
            self.isMain = display.isMain
        }
    }

    private let displayProvider: any DisplayProvider
    private let runner: any DisplayWallpaperRunner
    private var activeRuns: [String: ActiveRun] = [:]

    public init(displayProvider: any DisplayProvider, runner: any DisplayWallpaperRunner) {
        self.displayProvider = displayProvider
        self.runner = runner
    }

    public init(displayProvider: any DisplayProvider, harness: WallpaperHarness) {
        self.init(
            displayProvider: displayProvider,
            runner: WallpaperHarnessDisplayRunner(harness: harness)
        )
    }

    public func currentEnabledDisplays(settings: AppSettings) -> [DisplayTarget] {
        enabledDisplays(from: displayProvider.currentDisplays(), settings: settings)
    }

    @discardableResult
    public func refreshDisplays(settings: AppSettings) -> [DisplayTarget] {
        let currentDisplays = displayProvider.currentDisplays()
        let enabledDisplays = enabledDisplays(from: currentDisplays, settings: settings)
        cancelRunsNotIn(Set(enabledDisplays.map(\.id)))

        for display in enabledDisplays {
            _ = activeRun(for: display)
        }

        return enabledDisplays
    }

    public func runOnce(settings: AppSettings) async -> [DisplayRunResult] {
        let currentDisplays = displayProvider.currentDisplays()
        let enabledDisplays = enabledDisplays(from: currentDisplays, settings: settings)
        cancelRunsNotIn(Set(enabledDisplays.map(\.id)))
        let runs = enabledDisplays.map { activeRun(for: $0) }

        var results: [DisplayRunResult] = []
        results.reserveCapacity(runs.count)

        for run in runs {
            let result = await run.task.value
            clearActiveRun(displayID: result.display.id, token: run.token)
            results.append(result)
        }

        return results
    }

    public func cancelAllRunningTasks() {
        let runs = activeRuns.values
        activeRuns.removeAll()
        runs.forEach { $0.task.cancel() }
    }

    public func activeDisplayIDs() -> Set<String> {
        Set(activeRuns.keys)
    }

    private func enabledDisplays(
        from displays: [DisplayTarget],
        settings: AppSettings
    ) -> [DisplayTarget] {
        guard !settings.enabledDisplayIDs.isEmpty else {
            return displays
        }

        return displays.filter { settings.enabledDisplayIDs.contains($0.id) }
    }

    private func cancelRunsNotIn(_ enabledDisplayIDs: Set<String>) {
        for (displayID, activeRun) in activeRuns where !enabledDisplayIDs.contains(displayID) {
            activeRun.task.cancel()
            activeRuns[displayID] = nil
        }
    }

    private func activeRun(for display: DisplayTarget) -> ActiveRun {
        let signature = DisplaySignature(display: display)

        if let activeRun = activeRuns[display.id] {
            guard activeRun.signature != signature else {
                return activeRun
            }

            activeRun.task.cancel()
            activeRuns[display.id] = nil
        }

        let token = UUID()
        let task = makeTask(for: display, token: token)
        let activeRun = ActiveRun(token: token, signature: signature, task: task)
        activeRuns[display.id] = activeRun

        return activeRun
    }

    private func makeTask(
        for display: DisplayTarget,
        token: UUID
    ) -> Task<DisplayRunResult, Never> {
        let runner = runner

        return Task {
            let result: DisplayRunResult

            do {
                let harnessResult = try await runner.run(display: display)
                result = DisplayRunResult(
                    display: display,
                    state: harnessResult.state,
                    harnessResult: harnessResult,
                    errorDescription: harnessResult.state == .failed ? harnessResult.record.failureReason : nil
                )
            } catch is CancellationError {
                result = DisplayRunResult(
                    display: display,
                    state: .cancelled,
                    harnessResult: nil,
                    errorDescription: nil
                )
            } catch {
                result = DisplayRunResult(
                    display: display,
                    state: .failed,
                    harnessResult: nil,
                    errorDescription: Self.errorDescription(from: error)
                )
            }

            clearActiveRun(displayID: display.id, token: token)
            return result
        }
    }

    private func clearActiveRun(displayID: String, token: UUID) {
        guard activeRuns[displayID]?.token == token else {
            return
        }

        activeRuns[displayID] = nil
    }

    private nonisolated static func errorDescription(from error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            return description
        }

        return String(describing: error)
    }
}
