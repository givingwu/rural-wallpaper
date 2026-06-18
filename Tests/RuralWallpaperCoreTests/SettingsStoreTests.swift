import Foundation
import XCTest
@testable import RuralWallpaperCore

final class SettingsStoreTests: XCTestCase {
    func testDefaultRefreshFrequencyIsOncePerDay() {
        XCTAssertEqual(AppSettings.default.refreshIntervalHours, 24)
    }

    func testDefaultHistoryRetentionIsThirtyPerDisplay() {
        XCTAssertEqual(AppSettings.default.historyLimitPerDisplay, 30)
    }

    func testUserDefaultsSettingsStoreReturnsDefaultWhenNoSettingsAreSaved() throws {
        let (suiteName, userDefaults) = try makeIsolatedUserDefaults()
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let store = UserDefaultsSettingsStore(userDefaults: userDefaults)

        XCTAssertEqual(try store.load(), .default)
    }

    func testUserDefaultsSettingsStoreRoundTripsAppSettings() throws {
        let (suiteName, userDefaults) = try makeIsolatedUserDefaults()
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let store = UserDefaultsSettingsStore(userDefaults: userDefaults)
        let settings = AppSettings(
            autoUpdateEnabled: true,
            refreshIntervalHours: 12,
            maxBackgroundAttempts: 4,
            maxLayoutCandidates: 8,
            minimumScore: 0.82,
            historyLimitPerDisplay: 45,
            preferredThemes: ["field", "mist", "sunrise"],
            enabledDisplayIDs: ["built-in", "studio-display"]
        )

        try store.save(settings)

        XCTAssertEqual(try store.load(), settings)
    }

    func testUserDefaultsSettingsStoreThrowsWhenSavedSettingsCannotBeDecoded() throws {
        let (suiteName, userDefaults) = try makeIsolatedUserDefaults()
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        userDefaults.set(Data("not-json".utf8), forKey: UserDefaultsSettingsStore.settingsKey)

        let store = UserDefaultsSettingsStore(userDefaults: userDefaults)

        XCTAssertThrowsError(try store.load()) { error in
            guard case SettingsStoreError.failedToDecodeSettings = error else {
                return XCTFail("Expected failedToDecodeSettings, got \(error)")
            }
        }
    }

    func testMockSecretStoreCanSaveAndReadSecret() throws {
        let store = MockSecretStore()
        let ref = SecretRef(service: "RuralWallpaperTests", account: "default")

        try store.write("secret-value", for: ref)

        XCTAssertEqual(try store.read(ref), "secret-value")
    }

    private func makeIsolatedUserDefaults() throws -> (String, UserDefaults) {
        let suiteName = "RuralWallpaperCoreTests.SettingsStore.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))

        return (suiteName, userDefaults)
    }
}

private final class MockSecretStore: SecretStore, @unchecked Sendable {
    private var values: [String: String] = [:]

    func read(_ ref: SecretRef) throws -> String? {
        values[key(for: ref)]
    }

    func write(_ value: String, for ref: SecretRef) throws {
        values[key(for: ref)] = value
    }

    func delete(_ ref: SecretRef) throws {
        values.removeValue(forKey: key(for: ref))
    }

    private func key(for ref: SecretRef) -> String {
        "\(ref.service)#\(ref.account)"
    }
}
