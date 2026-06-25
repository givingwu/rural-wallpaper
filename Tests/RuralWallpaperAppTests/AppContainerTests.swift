import AppKit
import Foundation
import RuralWallpaperCore
@testable import RuralWallpaperApp
import XCTest

final class AppContainerTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "RuralWallpaperAppTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDisablingLastSelectedDisplayKeepsItEnabled() {
        let display = makeDisplay(id: "built-in")
        var settings = AppSettings.default
        settings.enabledDisplayIDs = [display.id]

        DisplaySelection.update(
            displayID: display.id,
            enabled: false,
            displays: [display],
            settings: &settings
        )

        XCTAssertEqual(settings.enabledDisplayIDs, [display.id])
    }

    func testDisablingOneDisplayFromAllEnabledMaterializesRemainingDisplays() {
        let first = makeDisplay(id: "built-in")
        let second = makeDisplay(id: "studio")
        var settings = AppSettings.default
        settings.enabledDisplayIDs = []

        DisplaySelection.update(
            displayID: first.id,
            enabled: false,
            displays: [first, second],
            settings: &settings
        )

        XCTAssertEqual(settings.enabledDisplayIDs, [second.id])
    }

    @MainActor
    func testInitializationReportsSettingsLoadFailure() {
        let container = AppContainer(
            settingsStore: FailingSettingsStore(loadError: TestError("load failed")),
            secretStore: InMemorySecretStore(),
            displayProvider: StaticTestDisplayProvider(displays: [makeDisplay(id: "built-in")]),
            userDefaults: userDefaults
        )

        XCTAssertEqual(container.settings, .default)
        XCTAssertEqual(container.lastErrorMessage, "load failed")
    }

    @MainActor
    func testInitializationReportsProviderSecretLoadFailure() {
        let secretStore = InMemorySecretStore()
        secretStore.readError = TestError("keychain unavailable")

        let container = AppContainer(
            settingsStore: StaticSettingsStore(settings: .default),
            secretStore: secretStore,
            displayProvider: StaticTestDisplayProvider(displays: [makeDisplay(id: "built-in")]),
            userDefaults: userDefaults
        )

        XCTAssertEqual(container.providerSettings.apiKey, "")
        XCTAssertEqual(container.lastErrorMessage, "keychain unavailable")
    }

    @MainActor
    func testSaveProviderSettingsDoesNotPersistUserDefaultsWhenSecretWriteFails() {
        let secretStore = InMemorySecretStore()
        secretStore.writeError = TestError("keychain write failed")
        let draft = ProviderSettingsDraft(
            baseURL: "https://example.test/v1",
            model: "example-model",
            apiKey: "example-secret",
            additionalHeaders: "X-Trace: app-test"
        )

        let container = AppContainer(
            settingsStore: StaticSettingsStore(settings: .default),
            secretStore: secretStore,
            displayProvider: StaticTestDisplayProvider(displays: [makeDisplay(id: "built-in")]),
            userDefaults: userDefaults
        )

        container.saveProviderSettings(draft)

        let reloaded = AppContainer(
            settingsStore: StaticSettingsStore(settings: .default),
            secretStore: InMemorySecretStore(),
            displayProvider: StaticTestDisplayProvider(displays: [makeDisplay(id: "built-in")]),
            userDefaults: userDefaults
        )
        XCTAssertEqual(container.providerSettings, .default)
        XCTAssertEqual(reloaded.providerSettings, .default)
        XCTAssertEqual(container.lastErrorMessage, "keychain write failed")
    }

    @MainActor
    func testTestProviderConnectionFailureDoesNotPersistDraftSettingsOrSecret() async {
        let secretStore = InMemorySecretStore()
        let draft = ProviderSettingsDraft(
            baseURL: "http://127.0.0.1:9/v1",
            model: "example-model",
            apiKey: "example-secret",
            additionalHeaders: ""
        )
        let container = AppContainer(
            settingsStore: StaticSettingsStore(settings: .default),
            secretStore: secretStore,
            displayProvider: StaticTestDisplayProvider(displays: [makeDisplay(id: "built-in")]),
            userDefaults: userDefaults
        )

        await container.testProviderConnection(draft)

        XCTAssertEqual(container.providerSettings, .default)
        XCTAssertNil(try secretStore.read(AppContainer.providerSecretRef))

        let reloaded = AppContainer(
            settingsStore: StaticSettingsStore(settings: .default),
            secretStore: secretStore,
            displayProvider: StaticTestDisplayProvider(displays: [makeDisplay(id: "built-in")]),
            userDefaults: userDefaults
        )
        XCTAssertEqual(reloaded.providerSettings, .default)
    }

    @MainActor
    func testProviderSettingsRejectUnsupportedURLSchemes() {
        let container = AppContainer(
            settingsStore: StaticSettingsStore(settings: .default),
            secretStore: InMemorySecretStore(),
            displayProvider: StaticTestDisplayProvider(displays: [makeDisplay(id: "built-in")]),
            userDefaults: userDefaults
        )
        let draft = ProviderSettingsDraft(
            baseURL: "ftp://example.test/v1",
            model: "example-model",
            apiKey: "example-secret",
            additionalHeaders: ""
        )

        container.saveProviderSettings(draft)

        XCTAssertEqual(container.providerSettings, .default)
        XCTAssertEqual(container.lastErrorMessage, "Base URL is invalid.")
    }

    @MainActor
    func testProviderSettingsRoundTripsUnsplashAccessKeyThroughKeychain() {
        let secretStore = InMemorySecretStore()
        let draft = ProviderSettingsDraft(
            baseURL: "https://example.test/v1",
            model: "vision-model",
            apiKey: "provider-secret",
            additionalHeaders: "",
            unsplashAccessKey: "unsplash-secret"
        )
        let container = AppContainer(
            settingsStore: StaticSettingsStore(settings: .default),
            secretStore: secretStore,
            displayProvider: StaticTestDisplayProvider(displays: [makeDisplay(id: "built-in")]),
            userDefaults: userDefaults
        )

        container.saveProviderSettings(draft)

        let reloaded = AppContainer(
            settingsStore: StaticSettingsStore(settings: .default),
            secretStore: secretStore,
            displayProvider: StaticTestDisplayProvider(displays: [makeDisplay(id: "built-in")]),
            userDefaults: userDefaults
        )
        XCTAssertEqual(reloaded.providerSettings.unsplashAccessKey, "unsplash-secret")
    }

    @MainActor
    func testGenerateGlassPreviewDoesNotApplyDesktopWallpaper() async throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let display = makeDisplay(id: "built-in")
        let setter = SpyDesktopWallpaperSetter()
        let container = AppContainer(
            settingsStore: StaticSettingsStore(settings: .default),
            secretStore: InMemorySecretStore(),
            displayProvider: StaticTestDisplayProvider(displays: [display]),
            userDefaults: userDefaults,
            supportDirectory: tempDirectory,
            previewSourceProvider: StaticPreviewSourceProvider(imageData: try makeTestPNG()),
            previewWordProvider: StaticImageFileWordProvider(words: previewWords()),
            previewDesktopSetter: setter
        )

        let preview = try await container.generateGlassPreview()

        XCTAssertEqual(container.activeGlassPreview, preview)
        XCTAssertTrue(FileManager.default.fileExists(atPath: preview.previewImageURL.path))
        XCTAssertEqual(
            preview.words.map(\.word),
            ["meadow", "ridge", "glow", "lantern", "harvest", "tranquil"]
        )
        XCTAssertEqual(container.generationProgressMessage, "Ready")
        XCTAssertTrue(setter.calls.isEmpty)
    }

    @MainActor
    func testGenerateGlassPreviewUsesSelectedPreviewDisplay() async throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let builtIn = makeDisplay(id: "built-in", isMain: true)
        let external = makeDisplay(id: "studio-display", isMain: false)
        var settings = AppSettings.default
        settings.selectedPreviewDisplayID = external.id
        let container = AppContainer(
            settingsStore: StaticSettingsStore(settings: settings),
            secretStore: InMemorySecretStore(),
            displayProvider: StaticTestDisplayProvider(displays: [builtIn, external]),
            userDefaults: userDefaults,
            supportDirectory: tempDirectory,
            previewSourceProvider: StaticPreviewSourceProvider(imageData: try makeTestPNG()),
            previewWordProvider: StaticImageFileWordProvider(words: previewWords()),
            previewDesktopSetter: SpyDesktopWallpaperSetter()
        )

        let preview = try await container.generateGlassPreview()

        XCTAssertEqual(preview.display, external)
    }

    @MainActor
    func testGenerateGlassPreviewFallsBackToMainDisplayWhenSelectedDisplayDisappears() async throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let builtIn = makeDisplay(id: "built-in", isMain: true)
        let external = makeDisplay(id: "studio-display", isMain: false)
        var settings = AppSettings.default
        settings.selectedPreviewDisplayID = "missing-display"
        let container = AppContainer(
            settingsStore: StaticSettingsStore(settings: settings),
            secretStore: InMemorySecretStore(),
            displayProvider: StaticTestDisplayProvider(displays: [external, builtIn]),
            userDefaults: userDefaults,
            supportDirectory: tempDirectory,
            previewSourceProvider: StaticPreviewSourceProvider(imageData: try makeTestPNG()),
            previewWordProvider: StaticImageFileWordProvider(words: previewWords()),
            previewDesktopSetter: SpyDesktopWallpaperSetter()
        )

        let preview = try await container.generateGlassPreview()

        XCTAssertEqual(preview.display, builtIn)
    }

    @MainActor
    func testSelectPreviewDisplayPersistsDisplayChoice() {
        let builtIn = makeDisplay(id: "built-in", isMain: true)
        let external = makeDisplay(id: "studio-display", isMain: false)
        let container = AppContainer(
            settingsStore: StaticSettingsStore(settings: .default),
            secretStore: InMemorySecretStore(),
            displayProvider: StaticTestDisplayProvider(displays: [builtIn, external]),
            userDefaults: userDefaults
        )

        container.selectPreviewDisplay(id: external.id)

        XCTAssertEqual(container.settings.selectedPreviewDisplayID, external.id)
        XCTAssertEqual(container.selectedPreviewDisplay?.id, external.id)
    }

    @MainActor
    func testApplyGlassPreviewSetsDesktopWallpaperOnlyAfterPreviewExists() async throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let display = makeDisplay(id: "built-in")
        let setter = SpyDesktopWallpaperSetter()
        let container = AppContainer(
            settingsStore: StaticSettingsStore(settings: .default),
            secretStore: InMemorySecretStore(),
            displayProvider: StaticTestDisplayProvider(displays: [display]),
            userDefaults: userDefaults,
            supportDirectory: tempDirectory,
            previewSourceProvider: StaticPreviewSourceProvider(imageData: try makeTestPNG()),
            previewWordProvider: StaticImageFileWordProvider(words: previewWords()),
            previewDesktopSetter: setter
        )

        let preview = try await container.generateGlassPreview()
        try container.applyGlassPreview()

        XCTAssertEqual(setter.calls, [
            WallpaperSetCall(fileURL: preview.previewImageURL, display: display)
        ])
    }

    @MainActor
    func testAutomaticPreviewUpdateGeneratesAndAppliesWallpaper() async throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let display = makeDisplay(id: "built-in")
        let setter = SpyDesktopWallpaperSetter()
        let logURL = tempDirectory.appendingPathComponent("test.log")
        var settings = AppSettings.default
        settings.autoUpdateEnabled = true
        let container = AppContainer(
            settingsStore: StaticSettingsStore(settings: settings),
            secretStore: InMemorySecretStore(),
            displayProvider: StaticTestDisplayProvider(displays: [display]),
            userDefaults: userDefaults,
            supportDirectory: tempDirectory,
            previewSourceProvider: StaticPreviewSourceProvider(imageData: try makeTestPNG()),
            previewWordProvider: StaticImageFileWordProvider(words: previewWords()),
            previewDesktopSetter: setter,
            logger: AppLogger(logFileURL: logURL)
        )

        let preview = try await container.runAutomaticPreviewUpdate()

        XCTAssertEqual(setter.calls, [
            WallpaperSetCall(fileURL: preview.previewImageURL, display: display)
        ])
        XCTAssertEqual(
            container.lastErrorMessage,
            "Auto update applied preview to built-in."
        )
        let log = try String(contentsOf: logURL, encoding: .utf8)
        assertLogOrder(
            log,
            [
                "auto_update.begin",
                "preview.begin",
                "apply.wallpaper.set.begin",
                "apply.wallpaper.set.done",
                "auto_update.done"
            ]
        )
    }

    @MainActor
    func testGenerateGlassPreviewWritesExecutionOrderToLog() async throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let display = makeDisplay(id: "built-in")
        let logURL = tempDirectory.appendingPathComponent("test.log")
        let container = AppContainer(
            settingsStore: StaticSettingsStore(settings: .default),
            secretStore: InMemorySecretStore(),
            displayProvider: StaticTestDisplayProvider(displays: [display]),
            userDefaults: userDefaults,
            supportDirectory: tempDirectory,
            previewSourceProvider: StaticPreviewSourceProvider(imageData: try makeTestPNG()),
            previewWordProvider: StaticImageFileWordProvider(words: previewWords()),
            previewDesktopSetter: SpyDesktopWallpaperSetter(),
            logger: AppLogger(logFileURL: logURL)
        )

        _ = try await container.generateGlassPreview()

        let log = try String(contentsOf: logURL, encoding: .utf8)
        XCTAssertTrue(log.contains("source.done"))
        XCTAssertTrue(log.contains("prompt=test"))
        XCTAssertTrue(log.contains("runID="))
        assertLogOrder(
            log,
            [
                "preview.begin",
                "display.selected",
                "preview.directory.create.begin",
                "preview.directory.create.done",
                "source.begin",
                "source.image.read.done",
                "source.done",
                "words.begin",
                "words.done count=6",
                "render.begin",
                "file.write.begin prefix=glass-preview",
                "file.write.done prefix=glass-preview",
                "render.done",
                "preview.done"
            ]
        )
    }

    @MainActor
    func testGenerateGlassPreviewFromSelectedImageUsesLocalImageSource() async throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let selectedImageURL = tempDirectory.appendingPathComponent("selected.png")
        try makeTestPNG().write(to: selectedImageURL)
        let display = makeDisplay(id: "built-in")
        let container = AppContainer(
            settingsStore: StaticSettingsStore(settings: .default),
            secretStore: InMemorySecretStore(),
            displayProvider: StaticTestDisplayProvider(displays: [display]),
            userDefaults: userDefaults,
            supportDirectory: tempDirectory,
            previewWordProvider: StaticImageFileWordProvider(words: previewWords()),
            previewDesktopSetter: SpyDesktopWallpaperSetter()
        )

        let preview = try await container.generateGlassPreview(from: selectedImageURL)

        XCTAssertEqual(preview.sourceImageURL.pathExtension, "png")
        XCTAssertNotEqual(preview.sourceImageURL, selectedImageURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: preview.previewImageURL.path))
        XCTAssertEqual(
            preview.words.map(\.word),
            ["meadow", "ridge", "glow", "lantern", "harvest", "tranquil"]
        )
    }

    @MainActor
    func testGenerateGlassPreviewRequestsConfiguredVocabularyCount() async throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let display = makeDisplay(id: "built-in")
        var settings = AppSettings.default
        settings.vocabularyWordCount = 6
        let wordProvider = SpyImageFileWordProvider(words: previewWords(count: 6))
        let container = AppContainer(
            settingsStore: StaticSettingsStore(settings: settings),
            secretStore: InMemorySecretStore(),
            displayProvider: StaticTestDisplayProvider(displays: [display]),
            userDefaults: userDefaults,
            supportDirectory: tempDirectory,
            previewSourceProvider: StaticPreviewSourceProvider(imageData: try makeTestPNG()),
            previewWordProvider: wordProvider,
            previewDesktopSetter: SpyDesktopWallpaperSetter()
        )

        let preview = try await container.generateGlassPreview()

        XCTAssertEqual(preview.words.count, 6)
        let targetCounts = await wordProvider.targetCounts
        XCTAssertEqual(targetCounts, [6])
    }

    @MainActor
    func testGenerateStatusTracksSelectedImageSourceTargetAndPreview() async throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let selectedImageURL = tempDirectory.appendingPathComponent("beijing-night.png")
        try makeTestPNG().write(to: selectedImageURL)
        let display = makeDisplay(id: "studio-display")
        let container = AppContainer(
            settingsStore: StaticSettingsStore(settings: .default),
            secretStore: InMemorySecretStore(),
            displayProvider: StaticTestDisplayProvider(displays: [display]),
            userDefaults: userDefaults,
            supportDirectory: tempDirectory,
            previewWordProvider: StaticImageFileWordProvider(words: previewWords()),
            previewDesktopSetter: SpyDesktopWallpaperSetter()
        )

        let preview = try await container.generateGlassPreview(from: selectedImageURL)
        let status = container.generateStatus

        XCTAssertEqual(status.phase, .done)
        XCTAssertEqual(status.source?.kind, .selectedImage)
        XCTAssertEqual(status.source?.originalURL, selectedImageURL)
        XCTAssertEqual(status.source?.workingURL, preview.sourceImageURL)
        XCTAssertEqual(status.target?.displayName, "studio-display")
        XCTAssertEqual(status.target?.pixelSize, PixelSize(width: 1440, height: 900))
        XCTAssertEqual(status.previewURL, preview.previewImageURL)
        XCTAssertEqual(status.wordCount, 6)
        XCTAssertTrue(status.primaryLine(now: Date()).hasPrefix("Done · "))
        XCTAssertEqual(status.sourceLine, "Source: Chosen image · beijing-night.png")
        XCTAssertEqual(status.targetLine, "Target: studio-display · 1440x900")
        XCTAssertEqual(status.previewLine, "Preview: \(preview.previewImageURL.lastPathComponent)")
    }

    @MainActor
    func testGenerateStatusReportsCLITimeout() async throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let display = makeDisplay(id: "built-in")
        let logURL = tempDirectory.appendingPathComponent("test.log")
        let container = AppContainer(
            settingsStore: StaticSettingsStore(settings: .default),
            secretStore: InMemorySecretStore(),
            displayProvider: StaticTestDisplayProvider(displays: [display]),
            userDefaults: userDefaults,
            supportDirectory: tempDirectory,
            previewSourceProvider: StaticPreviewSourceProvider(imageData: try makeTestPNG()),
            previewWordProvider: FailingImageFileWordProvider(
                error: CLIWordProviderError.commandTimedOut(command: .codex, timeoutSeconds: 180)
            ),
            previewDesktopSetter: SpyDesktopWallpaperSetter(),
            logger: AppLogger(logFileURL: logURL)
        )

        do {
            _ = try await container.generateGlassPreview()
            XCTFail("Expected timeout")
        } catch CLIWordProviderError.commandTimedOut {
            XCTAssertEqual(container.generateStatus.phase, .timedOut)
            XCTAssertEqual(container.generateStatus.errorSummary, "Codex CLI")
            XCTAssertEqual(container.generateStatus.primaryLine(now: Date()), "Timed out · Codex CLI · 03:00")
            XCTAssertEqual(container.generateStatus.sourceLine, "Source: Generated image · test")
            XCTAssertEqual(container.generateStatus.targetLine, "Target: built-in · 1440x900")
            let log = try String(contentsOf: logURL, encoding: .utf8)
            XCTAssertTrue(log.contains("preview.failed error=Codex CLI timed out after 180 seconds."))
            XCTAssertFalse(log.contains("执行超过"))
        }
    }

    private func makeDisplay(id: String, isMain: Bool = true) -> DisplayTarget {
        DisplayTarget(
            id: id,
            frame: CoreRect(x: 0, y: 0, width: 1440, height: 900),
            pixelSize: PixelSize(width: 1440, height: 900),
            scale: 1,
            colorSpace: "sRGB",
            isMain: isMain,
            friendlyName: id
        )
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("RuralWallpaperAppTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeTestPNG() throws -> Data {
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(
            CGContext(
                data: nil,
                width: 320,
                height: 180,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(CGColor(red: 0.08, green: 0.12, blue: 0.16, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 320, height: 180))
        let image = try XCTUnwrap(context.makeImage())
        let bitmap = NSBitmapImageRep(cgImage: image)
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }

    private func previewWords() -> [VocabularyItem] {
        previewWords(count: AppSettings.defaultVocabularyWordCount)
    }

    private func previewWords(count: Int) -> [VocabularyItem] {
        let base = [
            ("meadow", "草地"),
            ("ridge", "山脊"),
            ("glow", "微光"),
            ("lantern", "灯笼"),
            ("harvest", "收获"),
            ("tranquil", "宁静的"),
            ("orchard", "果园"),
            ("pasture", "牧场"),
            ("willow", "柳树"),
            ("courtyard", "庭院"),
            ("reflection", "倒影"),
            ("bloom", "花开")
        ]
        return (0..<count).map { index in
            let item = base[index % base.count]
            return VocabularyItem(
                word: index < base.count ? item.0 : "\(item.0)\(index)",
                partOfSpeech: "noun",
                zhDefinition: item.1,
                example: "The \(item.0) fits the wallpaper.",
                difficulty: 2,
                sourceReason: "Test fixture."
            )
        }
    }

    private func assertLogOrder(
        _ log: String,
        _ tokens: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var searchStart = log.startIndex
        for token in tokens {
            guard let range = log[searchStart...].range(of: token) else {
                XCTFail("Missing log token: \(token)\n\(log)", file: file, line: line)
                return
            }
            searchStart = range.upperBound
        }
    }
}

private struct TestError: Error, LocalizedError, Equatable {
    var message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}

private struct StaticSettingsStore: SettingsStore {
    var settings: AppSettings

    func load() throws -> AppSettings {
        settings
    }

    func save(_ settings: AppSettings) throws {}
}

private struct FailingSettingsStore: SettingsStore {
    var loadError: Error

    func load() throws -> AppSettings {
        throw loadError
    }

    func save(_ settings: AppSettings) throws {}
}

private final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    var readError: Error?
    var writeError: Error?
    var values: [String: String] = [:]

    func read(_ ref: SecretRef) throws -> String? {
        if let readError {
            throw readError
        }

        return values[key(for: ref)]
    }

    func write(_ value: String, for ref: SecretRef) throws {
        if let writeError {
            throw writeError
        }

        values[key(for: ref)] = value
    }

    func delete(_ ref: SecretRef) throws {
        values.removeValue(forKey: key(for: ref))
    }

    private func key(for ref: SecretRef) -> String {
        "\(ref.service):\(ref.account)"
    }
}

private struct StaticTestDisplayProvider: DisplayProvider {
    var displays: [DisplayTarget]

    func currentDisplays() -> [DisplayTarget] {
        displays
    }
}

private struct StaticPreviewSourceProvider: SourceProvider {
    let id = "static-preview"
    var imageData: Data

    func makeSourceImage(for display: DisplayTarget, settings: AppSettings) async throws -> SourceImage {
        SourceImage(
            imageData: imageData,
            attribution: .aiGenerated(
                AIGeneratedAttribution(
                    prompt: "test",
                    providerID: "test",
                    model: "test"
                )
            ),
            prompt: "test"
        )
    }
}

private struct StaticImageFileWordProvider: ImageFileWordProvider {
    var words: [VocabularyItem]

    func extractWords(from imageURL: URL, targetCount: Int) async throws -> [VocabularyItem] {
        words
    }
}

private struct FailingImageFileWordProvider: ImageFileWordProvider {
    var error: Error

    func extractWords(from imageURL: URL, targetCount: Int) async throws -> [VocabularyItem] {
        throw error
    }
}

private actor SpyImageFileWordProvider: ImageFileWordProvider {
    private let words: [VocabularyItem]
    private var recordedTargetCounts: [Int] = []

    init(words: [VocabularyItem]) {
        self.words = words
    }

    func extractWords(from imageURL: URL, targetCount: Int) async throws -> [VocabularyItem] {
        recordedTargetCounts.append(targetCount)
        return words
    }

    var targetCounts: [Int] {
        recordedTargetCounts
    }
}

private struct WallpaperSetCall: Equatable {
    var fileURL: URL
    var display: DisplayTarget
}

private final class SpyDesktopWallpaperSetter: DesktopWallpaperSetter, @unchecked Sendable {
    var calls: [WallpaperSetCall] = []

    func setWallpaper(fileURL: URL, for display: DisplayTarget) throws {
        calls.append(WallpaperSetCall(fileURL: fileURL, display: display))
    }
}
