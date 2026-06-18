import XCTest
@testable import RuralWallpaperCore

final class SmokeTests: XCTestCase {
    func testCoreModuleExposesVersion() {
        XCTAssertEqual(RuralWallpaperCore.version, "0.1.0")
    }
}
