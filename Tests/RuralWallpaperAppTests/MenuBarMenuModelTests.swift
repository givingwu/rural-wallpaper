import XCTest
import RuralWallpaperCore
@testable import RuralWallpaperApp

final class MenuBarMenuModelTests: XCTestCase {
    func testMenuSectionsUseRequestedOrder() {
        let sections = MenuBarMenuModel.sections(
            isGenerating: false,
            hasLastPreview: true,
            generateStatus: .idle()
        )

        XCTAssertEqual(
            sections.map { $0.items.map(\.title) },
            [
                ["Generate Status", "Ready"],
                ["Select Display", "Choose Image", "Generate Preview"],
                ["Open Last Preview", "Open Logs"],
                ["Settings", "Quit"]
            ]
        )
    }

    func testGeneratingMenuShowsStatusBeforeActions() {
        let startedAt = Date(timeIntervalSince1970: 100)
        let imageURL = URL(fileURLWithPath: "/tmp/beijing-night.jpg")
        let status = GenerateStatus(
            runID: "run-test",
            phase: .extractingWords,
            mode: .manual,
            startedAt: startedAt,
            finishedAt: nil,
            timeoutSeconds: 180,
            source: GenerateSourceSummary(
                kind: .selectedImage,
                originalURL: imageURL,
                workingURL: nil,
                prompt: "Selected local image"
            ),
            target: GenerateTargetSummary(
                displayName: "PHL 279P1",
                displayID: "external",
                pixelSize: PixelSize(width: 6016, height: 3384)
            ),
            previewURL: nil,
            wordCount: nil,
            errorSummary: nil
        )

        let sections = MenuBarMenuModel.sections(
            isGenerating: true,
            hasLastPreview: false,
            generateStatus: status,
            now: Date(timeIntervalSince1970: 172)
        )

        XCTAssertEqual(
            sections.first?.items.map(\.title),
            [
                "Generate Status",
                "Generating · Extracting words · 01:12 / 03:00",
                "Source: Chosen image · beijing-night.jpg",
                "Target: PHL 279P1 · 6016x3384"
            ]
        )
        XCTAssertEqual(sections.first?.items[1].role, .loading)
        XCTAssertEqual(sections.first?.items[1].isEnabled, false)
        XCTAssertTrue(
            sections.dropFirst().first?.items.contains {
                $0.title == "Cancel Generation" && $0.role == .action
            } == true
        )
    }

    func testDoneMenuShowsSourceWorkingImageAndWordCounts() {
        let startedAt = Date(timeIntervalSince1970: 100)
        let finishedAt = Date(timeIntervalSince1970: 108)
        let originalURL = URL(fileURLWithPath: "/tmp/original-wallpaper.heic")
        let workingURL = URL(fileURLWithPath: "/tmp/RuralWallpaper/source-built-in.png")
        let previewURL = URL(fileURLWithPath: "/tmp/RuralWallpaper/glass-preview-built-in.png")
        let status = GenerateStatus(
            runID: "run-test",
            phase: .done,
            mode: .manual,
            startedAt: startedAt,
            finishedAt: finishedAt,
            timeoutSeconds: 180,
            source: GenerateSourceSummary(
                kind: .screenWallpaper,
                originalURL: originalURL,
                workingURL: workingURL,
                prompt: "Current desktop wallpaper"
            ),
            target: GenerateTargetSummary(
                displayName: "Built-in Retina Display",
                displayID: "built-in",
                pixelSize: PixelSize(width: 2880, height: 1800)
            ),
            previewURL: previewURL,
            wordCount: 24,
            selectedWordCount: 6,
            errorSummary: nil
        )

        let sections = MenuBarMenuModel.sections(
            isGenerating: false,
            hasLastPreview: true,
            generateStatus: status,
            now: Date(timeIntervalSince1970: 108)
        )

        XCTAssertEqual(
            sections.first?.items.map(\.title),
            [
                "Generate Status",
                "Done · 00:08 · 24 generated · 6 visible",
                "Source: Screen wallpaper · original-wallpaper.heic",
                "Working image: source-built-in.png",
                "Target: Built-in Retina Display · 2880x1800",
                "Words: 24 generated · 6 visible",
                "Preview: glass-preview-built-in.png"
            ]
        )
    }
}
