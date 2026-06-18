import Foundation
import XCTest
@testable import RuralWallpaperCore

final class HistoryStoreTests: XCTestCase {
    func testAppendAndReadSuccessRecordForDisplay() throws {
        let store = try makeStore()
        let display = makeDisplay(id: "display-a")
        let record = makeRecord(id: "success-1", display: display)

        try store.append(record)

        XCTAssertEqual(try store.recent(displayID: display.id, limit: 10), [record])
    }

    func testAppendAndReadFailureRecord() throws {
        let store = try makeStore()
        let display = makeDisplay(id: "display-failure")
        let record = makeRecord(
            id: "failure-1",
            display: display,
            finalImageURL: nil,
            failureReason: "No layout candidate passed the visual threshold."
        )

        try store.append(record)

        let recent = try store.recent(displayID: display.id, limit: 10)
        XCTAssertEqual(recent, [record])
        XCTAssertEqual(recent.first?.failureReason, record.failureReason)
        XCTAssertNil(recent.first?.finalImageURL)
    }

    func testRecentFiltersByDisplayAndReturnsNewestFirst() throws {
        let store = try makeStore()
        let firstDisplay = makeDisplay(id: "display-a")
        let secondDisplay = makeDisplay(id: "display-b")
        let oldRecord = makeRecord(
            id: "old",
            display: firstDisplay,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let otherDisplayRecord = makeRecord(
            id: "other",
            display: secondDisplay,
            createdAt: Date(timeIntervalSince1970: 200)
        )
        let newRecord = makeRecord(
            id: "new",
            display: firstDisplay,
            createdAt: Date(timeIntervalSince1970: 300)
        )

        try store.append(oldRecord)
        try store.append(otherDisplayRecord)
        try store.append(newRecord)

        XCTAssertEqual(
            try store.recent(displayID: firstDisplay.id, limit: 10),
            [newRecord, oldRecord]
        )
    }

    func testRetainsOnlyLatestThirtyRecordsPerDisplay() throws {
        let store = try makeStore()
        let firstDisplay = makeDisplay(id: "display-a")
        let secondDisplay = makeDisplay(id: "display-b")

        for index in 0..<35 {
            try store.append(makeRecord(
                id: "display-a-\(index)",
                display: firstDisplay,
                createdAt: Date(timeIntervalSince1970: TimeInterval(index))
            ))
        }
        try store.append(makeRecord(
            id: "display-b-old",
            display: secondDisplay,
            createdAt: Date(timeIntervalSince1970: 1)
        ))

        let firstDisplayRecords = try store.recent(displayID: firstDisplay.id, limit: 100)
        let secondDisplayRecords = try store.recent(displayID: secondDisplay.id, limit: 100)

        XCTAssertEqual(firstDisplayRecords.count, 30)
        XCTAssertEqual(firstDisplayRecords.first?.id, "display-a-34")
        XCTAssertEqual(firstDisplayRecords.last?.id, "display-a-5")
        XCTAssertEqual(secondDisplayRecords.map(\.id), ["display-b-old"])
    }

    func testStoredJSONDoesNotContainSensitiveProviderCredentials() throws {
        let (store, storageURL) = try makeStoreWithURL()
        let record = makeRecord(
            id: "safe-record",
            display: makeDisplay(id: "display-safe"),
            providerID: "openai-compatible"
        )

        try store.append(record)

        let json = try String(contentsOf: storageURL, encoding: .utf8)
        XCTAssertFalse(json.localizedCaseInsensitiveContains("apiKey"))
        XCTAssertFalse(json.localizedCaseInsensitiveContains("Bearer "))
        XCTAssertNil(json.range(of: #"sk-[A-Za-z0-9_-]{6,}"#, options: .regularExpression))
    }

    func testAppendRejectsRecordsThatWouldPersistSensitiveData() throws {
        let (store, storageURL) = try makeStoreWithURL()
        let record = makeRecord(
            id: "unsafe-record",
            display: makeDisplay(id: "display-unsafe"),
            failureReason: "Provider rejected Bearer redacted-token"
        )

        XCTAssertThrowsError(try store.append(record)) { error in
            guard case HistoryStoreError.sensitiveDataDetected = error else {
                return XCTFail("Expected sensitiveDataDetected, got \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: storageURL.path))
    }

    private func makeStore() throws -> FileHistoryStore {
        try makeStoreWithURL().store
    }

    private func makeStoreWithURL() throws -> (store: FileHistoryStore, storageURL: URL) {
        let directory = try makeTemporaryDirectory()
        let storageURL = directory.appendingPathComponent("history.json")

        return (FileHistoryStore(storageURL: storageURL), storageURL)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RuralWallpaperHistoryStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        return directory
    }

    private func makeRecord(
        id: String,
        display: DisplayTarget,
        finalImageURL: URL? = URL(fileURLWithPath: "/tmp/final.png"),
        providerID: String = "ai-source",
        createdAt: Date = Date(timeIntervalSince1970: 1_000),
        failureReason: String? = nil
    ) -> GeneratedWallpaper {
        GeneratedWallpaper(
            id: id,
            finalImageURL: finalImageURL,
            sourceImageURL: URL(fileURLWithPath: "/tmp/source.png"),
            display: display,
            words: VocabularyItem.samples(count: 3),
            layout: LayoutPlan(
                displayID: display.id,
                wordPlacements: [
                    LayoutWordPlacement(
                        word: "meadow",
                        rect: CoreRect(x: 120, y: 90, width: 300, height: 80),
                        baseline: CorePoint(x: 120, y: 140),
                        fontSize: 64,
                        depth: 0.4,
                        opacity: 0.92
                    )
                ],
                depthMode: .depthAware,
                score: 0.91
            ),
            evaluation: EvaluationResult(
                readability: 0.95,
                sceneFit: 0.9,
                depthBelievability: 0.86,
                desktopCalmness: 0.93,
                wordRelevance: 0.97,
                noBadOcclusion: 0.96,
                textCorrectness: 1.0,
                notes: "good"
            ),
            attribution: SourceAttribution.aiGenerated(
                AIGeneratedAttribution(
                    prompt: "quiet rural desktop wallpaper, no text",
                    providerID: providerID,
                    model: "image-model"
                )
            ),
            providerID: providerID,
            createdAt: createdAt,
            failureReason: failureReason
        )
    }

    private func makeDisplay(id: String) -> DisplayTarget {
        DisplayTarget(
            id: id,
            frame: CoreRect(x: 0, y: 0, width: 1440, height: 900),
            pixelSize: PixelSize(width: 2880, height: 1800),
            scale: 2,
            colorSpace: "sRGB",
            isMain: true,
            friendlyName: "Built-in Display"
        )
    }
}
