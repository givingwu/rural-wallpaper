import XCTest
@testable import RuralWallpaperCore

final class MenuBarStateTests: XCTestCase {
    func testGeneratingStateDisablesDuplicateManualGeneration() {
        var state = MenuBarState()

        XCTAssertTrue(state.beginManualGeneration())
        XCTAssertFalse(state.beginManualGeneration())
        XCTAssertTrue(state.isGenerating)
    }

    func testPausedStatePreventsAutomaticUpdateEvenWhenDue() {
        var state = MenuBarState(lastGeneratedAt: Date(timeIntervalSince1970: 0))
        state.setPaused(true)
        let settings = AppSettings.default.withAutoUpdate(enabled: true, refreshIntervalHours: 1)

        XCTAssertFalse(
            state.shouldRunAutomaticUpdate(
                settings: settings,
                now: Date(timeIntervalSince1970: 3_600)
            )
        )
    }

    func testFailureStateShowsRecentErrorSummary() {
        var state = MenuBarState()

        state.finishWithFailure("The provider rejected the image because the score was below threshold.")

        XCTAssertFalse(state.isGenerating)
        XCTAssertEqual(
            state.recentErrorSummary,
            "The provider rejected the image because the score was below threshold."
        )
        XCTAssertEqual(
            state.statusTitle,
            "Failed: The provider rejected the image because the score was below threshold."
        )
    }
}

private extension AppSettings {
    func withAutoUpdate(enabled: Bool, refreshIntervalHours: Int) -> AppSettings {
        AppSettings(
            autoUpdateEnabled: enabled,
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
