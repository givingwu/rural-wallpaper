import ImageIO
import XCTest
@testable import RuralWallpaperCore

final class EndToEndMockFlowTests: XCTestCase {
    func testMockFlowGeneratesReadableWallpaperSetsDesktopAndRecordsHistory() async throws {
        let outputDirectory = try makeTemporaryDirectory()
        let display = makeDisplay()
        let desktopSetter = RecordingDesktopWallpaperSetter()
        let historyStore = RecordingHistoryStore()
        let harness = WallpaperHarness(
            sourceProvider: MockSourceProvider(),
            aiProvider: MockPreviewProvider(),
            layoutPlanner: WordLayoutPlanner(),
            renderEngine: CoreGraphicsRenderEngine(),
            desktopSetter: desktopSetter,
            historyStore: historyStore,
            outputDirectory: outputDirectory,
            compositionMode: .cleanSourceImage,
            settings: AppSettings.default
        )

        let result = try await harness.run(display: display)
        let finalURL = try XCTUnwrap(result.record.finalImageURL)
        let imageSource = CGImageSourceCreateWithURL(finalURL as CFURL, nil)

        XCTAssertEqual(result.state, .succeeded)
        XCTAssertEqual(desktopSetter.calls.count, 1)
        XCTAssertEqual(desktopSetter.calls.first?.fileURL, finalURL)
        XCTAssertEqual(desktopSetter.calls.first?.display, display)
        XCTAssertEqual(historyStore.records, [result.record])
        XCTAssertTrue((3...5).contains(result.record.words.count))
        XCTAssertNil(result.record.layout)
        XCTAssertNil(result.record.evaluation)
        XCTAssertTrue(FileManager.default.fileExists(atPath: finalURL.path))
        XCTAssertNotNil(imageSource)
        XCTAssertNotNil(CGImageSourceCreateImageAtIndex(try XCTUnwrap(imageSource), 0, nil))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EndToEndMockFlowTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }

        return directory
    }

    private func makeDisplay() -> DisplayTarget {
        DisplayTarget(
            id: "mock-display",
            frame: CoreRect(x: 0, y: 0, width: 480, height: 300),
            pixelSize: PixelSize(width: 480, height: 300),
            scale: 1,
            colorSpace: "sRGB",
            isMain: true,
            friendlyName: "Mock Display"
        )
    }
}

private final class RecordingDesktopWallpaperSetter: DesktopWallpaperSetter, @unchecked Sendable {
    private(set) var calls: [(fileURL: URL, display: DisplayTarget)] = []

    func setWallpaper(fileURL: URL, for display: DisplayTarget) throws {
        calls.append((fileURL, display))
    }
}

private final class RecordingHistoryStore: HistoryStore, @unchecked Sendable {
    private(set) var records: [GeneratedWallpaper] = []

    func append(_ record: GeneratedWallpaper) throws {
        records.append(record)
    }

    func recent(displayID: String, limit: Int) throws -> [GeneratedWallpaper] {
        Array(records.filter { $0.display.id == displayID }.suffix(limit))
    }
}
