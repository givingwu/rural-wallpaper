import Foundation
import XCTest

final class PackagingScriptTests: XCTestCase {
    func testPackagingScriptBuildsAppIconIntoBundle() throws {
        let root = repositoryRoot()
        let packageScript = root.appendingPathComponent("scripts/package-macos.sh")
        let iconScript = root.appendingPathComponent("scripts/make-app-icon.swift")
        let workflow = root.appendingPathComponent(".github/workflows/release.yml")

        XCTAssertTrue(FileManager.default.fileExists(atPath: packageScript.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: iconScript.path))

        let packageSource = try String(contentsOf: packageScript, encoding: .utf8)
        XCTAssertTrue(packageSource.contains("CFBundleIconFile"))
        XCTAssertTrue(packageSource.contains("AppIcon.icns"))
        XCTAssertTrue(packageSource.contains("make-app-icon.swift"))
        XCTAssertTrue(packageSource.contains("iconutil -c icns"))

        let workflowSource = try String(contentsOf: workflow, encoding: .utf8)
        XCTAssertTrue(workflowSource.contains("scripts/package-macos.sh"))
        XCTAssertTrue(workflowSource.contains("runs-on: macos-15"))
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
