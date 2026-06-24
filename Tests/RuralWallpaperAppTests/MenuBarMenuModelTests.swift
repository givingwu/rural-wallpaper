import XCTest
@testable import RuralWallpaperApp

final class MenuBarMenuModelTests: XCTestCase {
    func testMenuSectionsUseRequestedOrder() {
        let sections = MenuBarMenuModel.sections(
            isGenerating: false,
            hasLastPreview: true
        )

        XCTAssertEqual(
            sections.map { $0.items.map(\.title) },
            [
                ["Select Display", "Choose Image", "Generate Preview"],
                ["Open Last Preview", "Open Logs"],
                ["Settings", "Quit"]
            ]
        )
    }

    func testGeneratingMenuShowsLoadingBeforeActions() {
        let sections = MenuBarMenuModel.sections(
            isGenerating: true,
            hasLastPreview: false
        )

        XCTAssertEqual(sections.first?.items.first?.role, .loading)
        XCTAssertEqual(sections.first?.items.first?.title, "Generating")
        XCTAssertTrue(
            sections.first?.items.contains {
                $0.title == "Cancel Generation" && $0.role == .action
            } == true
        )
    }
}
