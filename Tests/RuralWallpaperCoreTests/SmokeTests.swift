import Foundation
import XCTest
@testable import RuralWallpaperCore

final class SmokeTests: XCTestCase {
    func testCoreModuleExposesVersion() {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        guard let releaseVersion = try? String(
            contentsOf: root.appendingPathComponent("version.txt"),
            encoding: .utf8
        ).trimmingCharacters(in: .whitespacesAndNewlines) else {
            return XCTFail("Could not read version.txt")
        }

        XCTAssertEqual(RuralWallpaperCore.version, releaseVersion)
    }
}
