import Foundation
import RuralWallpaperCore
import SwiftUI

struct ProviderSettingsDraft: Equatable {
    var baseURL: String
    var model: String
    var apiKey: String
    var additionalHeaders: String

    static let `default` = ProviderSettingsDraft(
        baseURL: "https://api.openai.com/v1",
        model: "gpt-4.1-mini",
        apiKey: "",
        additionalHeaders: ""
    )
}

enum AppContainerError: Error, LocalizedError {
    case invalidBaseURL
    case invalidHeaderLine(String)
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "Base URL is invalid."
        case .invalidHeaderLine(let line):
            "Header must use `Name: Value`: \(line)"
        case .missingAPIKey:
            "API Key is required."
        }
    }
}

@MainActor
final class AppContainer: ObservableObject {
    static let providerSecretRef = SecretRef(
        service: "RuralWallpaper",
        account: "default-provider"
    )

    @Published private(set) var settings: AppSettings
    @Published private(set) var providerSettings: ProviderSettingsDraft
    @Published private(set) var displays: [DisplayTarget]
    @Published var lastErrorMessage: String?

    private let settingsStore: any SettingsStore
    private let secretStore: any SecretStore
    private let historyStore: any HistoryStore
    private let displayProvider: any DisplayProvider
    private let userDefaults: UserDefaults

    init(
        settingsStore: any SettingsStore = UserDefaultsSettingsStore(),
        secretStore: any SecretStore = KeychainSecretStore(),
        displayProvider: any DisplayProvider = NSScreenDisplayProvider(),
        historyStore: (any HistoryStore)? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.settingsStore = settingsStore
        self.secretStore = secretStore
        self.displayProvider = displayProvider
        self.userDefaults = userDefaults

        let loadedSettings = (try? settingsStore.load()) ?? .default
        self.settings = loadedSettings
        self.historyStore = historyStore ?? FileHistoryStore(
            storageURL: Self.applicationSupportDirectory()
                .appendingPathComponent("history.json"),
            retentionLimitPerDisplay: loadedSettings.historyLimitPerDisplay
        )
        self.providerSettings = Self.loadProviderSettings(
            userDefaults: userDefaults,
            secretStore: secretStore
        )
        self.displays = displayProvider.currentDisplays()
    }

    func reloadDisplays() {
        displays = displayProvider.currentDisplays()
    }

    func saveGenerationSettings(_ newSettings: AppSettings) {
        do {
            try settingsStore.save(newSettings)
            settings = newSettings
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = Self.describe(error)
        }
    }

    func saveProviderSettings(_ draft: ProviderSettingsDraft) {
        do {
            _ = try makeProviderConfig(from: draft)
            userDefaults.set(draft.baseURL, forKey: ProviderDefaults.baseURL)
            userDefaults.set(draft.model, forKey: ProviderDefaults.model)
            userDefaults.set(draft.additionalHeaders, forKey: ProviderDefaults.additionalHeaders)

            // API Key 写入 Keychain，不进入 UserDefaults 或 JSON 配置。
            if draft.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try secretStore.delete(Self.providerSecretRef)
            } else {
                try secretStore.write(draft.apiKey, for: Self.providerSecretRef)
            }

            providerSettings = draft
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = Self.describe(error)
        }
    }

    func validateProviderSettings(_ draft: ProviderSettingsDraft) {
        do {
            _ = try makeProviderConfig(from: draft)
            if draft.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw AppContainerError.missingAPIKey
            }
            lastErrorMessage = "Provider settings are valid."
        } catch {
            lastErrorMessage = Self.describe(error)
        }
    }

    func recentHistory(limitPerDisplay: Int? = nil) -> [GeneratedWallpaper] {
        do {
            let currentDisplays = displays.isEmpty ? displayProvider.currentDisplays() : displays
            let limit = limitPerDisplay ?? settings.historyLimitPerDisplay
            let records = try currentDisplays.flatMap { display in
                try historyStore.recent(displayID: display.id, limit: limit)
            }

            lastErrorMessage = nil
            return records.sorted { $0.createdAt > $1.createdAt }
        } catch {
            lastErrorMessage = Self.describe(error)
            return []
        }
    }

    private func makeProviderConfig(from draft: ProviderSettingsDraft) throws -> ProviderConfig {
        guard let baseURL = URL(string: draft.baseURL), baseURL.scheme != nil else {
            throw AppContainerError.invalidBaseURL
        }

        return try ProviderConfig(
            id: "default",
            name: "Default",
            baseURL: baseURL,
            model: draft.model.trimmingCharacters(in: .whitespacesAndNewlines),
            secretRef: Self.providerSecretRef,
            additionalHeaders: try Self.parseHeaders(draft.additionalHeaders),
            capabilities: [.vision, .imageGeneration, .structuredOutput]
        )
    }

    private static func loadProviderSettings(
        userDefaults: UserDefaults,
        secretStore: any SecretStore
    ) -> ProviderSettingsDraft {
        ProviderSettingsDraft(
            baseURL: userDefaults.string(forKey: ProviderDefaults.baseURL)
                ?? ProviderSettingsDraft.default.baseURL,
            model: userDefaults.string(forKey: ProviderDefaults.model)
                ?? ProviderSettingsDraft.default.model,
            apiKey: (try? secretStore.read(Self.providerSecretRef)) ?? "",
            additionalHeaders: userDefaults.string(forKey: ProviderDefaults.additionalHeaders)
                ?? ProviderSettingsDraft.default.additionalHeaders
        )
    }

    private static func parseHeaders(_ rawValue: String) throws -> [String: String] {
        var headers: [String: String] = [:]

        for rawLine in rawValue.split(whereSeparator: \.isNewline) {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else {
                continue
            }

            guard let separator = line.firstIndex(of: ":") else {
                throw AppContainerError.invalidHeaderLine(line)
            }

            let name = String(line[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(line[line.index(after: separator)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !value.isEmpty else {
                throw AppContainerError.invalidHeaderLine(line)
            }

            headers[name] = value
        }

        return headers
    }

    private static func applicationSupportDirectory() -> URL {
        let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        let directory = baseURL.appendingPathComponent("RuralWallpaper", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private static func describe(_ error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }

        return String(describing: error)
    }
}

private enum ProviderDefaults {
    static let baseURL = "RuralWallpaper.Provider.BaseURL"
    static let model = "RuralWallpaper.Provider.Model"
    static let additionalHeaders = "RuralWallpaper.Provider.AdditionalHeaders"
}
