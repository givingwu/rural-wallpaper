import Foundation
import XCTest

final class PackagingScriptTests: XCTestCase {
    func testPackagingScriptBuildsAppIconIntoBundle() throws {
        let root = repositoryRoot()
        let packageScript = root.appendingPathComponent("scripts/build-app.sh")
        let iconScript = root.appendingPathComponent("scripts/make-app-icon.swift")
        let infoPlist = root.appendingPathComponent("Resources/Info.plist")
        let versionCheck = root.appendingPathComponent("scripts/check-version.py")
        let ciWorkflow = root.appendingPathComponent(".github/workflows/ci.yml")
        let workflow = root.appendingPathComponent(".github/workflows/release.yml")

        XCTAssertTrue(FileManager.default.fileExists(atPath: packageScript.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: iconScript.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: infoPlist.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: versionCheck.path))

        let packageSource = try String(contentsOf: packageScript, encoding: .utf8)
        XCTAssertTrue(packageSource.contains("AppIcon.icns"))
        XCTAssertTrue(packageSource.contains("make-app-icon.swift"))
        XCTAssertTrue(packageSource.contains("iconutil -c icns"))

        let plistSource = try String(contentsOf: infoPlist, encoding: .utf8)
        XCTAssertTrue(plistSource.contains("CFBundleIconFile"))
        XCTAssertTrue(plistSource.contains("x-release-please-version"))

        let coreVersionSource = try String(
            contentsOf: root.appendingPathComponent("Sources/RuralWallpaperCore/RuralWallpaperCore.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(coreVersionSource.contains("x-release-please-version"))

        let workflowSource = try String(contentsOf: workflow, encoding: .utf8)
        XCTAssertTrue(workflowSource.contains("scripts/package-release.sh"))
        XCTAssertTrue(workflowSource.contains("runs-on: macos-15"))

        let ciSource = try String(contentsOf: ciWorkflow, encoding: .utf8)
        XCTAssertTrue(ciSource.contains("swift test --quiet"))
        XCTAssertTrue(ciSource.contains("scripts/build-app.sh"))
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
