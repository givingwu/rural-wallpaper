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
}
