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

    private func makeDisplay(id: String) -> DisplayTarget {
        DisplayTarget(
            id: id,
            frame: CoreRect(x: 0, y: 0, width: 1440, height: 900),
            pixelSize: PixelSize(width: 1440, height: 900),
            scale: 1,
            colorSpace: "sRGB",
            isMain: true,
            friendlyName: id
        )
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
