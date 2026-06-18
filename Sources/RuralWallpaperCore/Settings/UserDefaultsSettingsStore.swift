import Foundation

public final class UserDefaultsSettingsStore: SettingsStore, @unchecked Sendable {
    private static let settingsKey = "RuralWallpaper.AppSettings.v1"

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func load() throws -> AppSettings {
        guard let data = userDefaults.data(forKey: Self.settingsKey) else {
            return .default
        }

        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            throw SettingsStoreError.failedToDecodeSettings(error.localizedDescription)
        }
    }

    public func save(_ settings: AppSettings) throws {
        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: Self.settingsKey)
        } catch {
            throw SettingsStoreError.failedToEncodeSettings(error.localizedDescription)
        }
    }
}
