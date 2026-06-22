import Foundation
import RuralWallpaperCore
import SwiftUI

struct ProviderSettingsDraft: Equatable {
    var baseURL: String
    var model: String
    var apiKey: String
    var additionalHeaders: String
    var unsplashAccessKey: String

    init(
        baseURL: String,
        model: String,
        apiKey: String,
        additionalHeaders: String,
        unsplashAccessKey: String = ""
    ) {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.additionalHeaders = additionalHeaders
        self.unsplashAccessKey = unsplashAccessKey
    }

    static let `default` = ProviderSettingsDraft(
        baseURL: "https://api.openai.com/v1",
        model: "gpt-4.1-mini",
        apiKey: "",
        additionalHeaders: "",
        unsplashAccessKey: ""
    )
}

enum ProviderMode: String {
    case mockPreview
    case realProvider

    var title: String {
        switch self {
        case .mockPreview:
            "Mock Preview"
        case .realProvider:
            "Real Provider"
        }
    }
}

enum AppContainerError: Error, LocalizedError {
    case invalidBaseURL
    case invalidHeaderLine(String)
    case missingAPIKey
    case missingUnsplashAccessKey
    case noDisplaysAvailable
    case mockGenerationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "Base URL is invalid."
        case .invalidHeaderLine(let line):
            "Header must use `Name: Value`: \(line)"
        case .missingAPIKey:
            "API Key is required."
        case .missingUnsplashAccessKey:
            "Unsplash Access Key is required."
        case .noDisplaysAvailable:
            "No display is available."
        case .mockGenerationFailed(let message):
            message
        }
    }
}

@MainActor
final class AppContainer: ObservableObject {
    static let providerSecretRef = SecretRef(
        service: "RuralWallpaper",
        account: "default-provider"
    )
    static let unsplashSecretRef = SecretRef(
        service: "RuralWallpaper",
        account: "unsplash-access-key"
    )

    @Published private(set) var settings: AppSettings
    @Published private(set) var providerSettings: ProviderSettingsDraft
    @Published private(set) var displays: [DisplayTarget]
    @Published private(set) var lastGeneratedWallpaperURLs: [URL] = []
    @Published private(set) var providerMode: ProviderMode = .mockPreview
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

        var startupMessages: [String] = []
        let loadedSettings: AppSettings
        do {
            loadedSettings = try settingsStore.load()
        } catch {
            loadedSettings = .default
            startupMessages.append(Self.describe(error))
        }

        self.settings = loadedSettings
        self.historyStore = historyStore ?? FileHistoryStore(
            storageURL: Self.applicationSupportDirectory()
                .appendingPathComponent("history.json"),
            retentionLimitPerDisplay: loadedSettings.historyLimitPerDisplay
        )
        let loadedProviderSettings = Self.loadProviderSettings(
            userDefaults: userDefaults,
            secretStore: secretStore
        )
        self.providerSettings = loadedProviderSettings.draft
        if let providerLoadError = loadedProviderSettings.error {
            startupMessages.append(Self.describe(providerLoadError))
        }
        self.displays = displayProvider.currentDisplays()
        self.lastErrorMessage = startupMessages.isEmpty
            ? nil
            : startupMessages.joined(separator: "\n")
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
            let previousSettings = providerSettings
            _ = try persistProviderSettings(draft)
            providerSettings = draft
            if draft != previousSettings {
                providerMode = .mockPreview
            }
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = Self.describe(error)
        }
    }

    func testProviderConnection(_ draft: ProviderSettingsDraft) async {
        do {
            if draft.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw AppContainerError.missingAPIKey
            }

            let config = try makeProviderConfig(from: draft)
            let provider = OpenAICompatibleProvider(
                config: config,
                secretStore: DraftSecretStore(
                    secretRef: Self.providerSecretRef,
                    secret: draft.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
            let result = try await provider.testConnection()
            _ = try persistProviderSettings(draft)
            providerSettings = draft
            providerMode = .realProvider
            lastErrorMessage = "Connected \(result.model)."
        } catch {
            providerMode = .mockPreview
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

    func runWallpaperFlow() async throws -> [WallpaperHarnessResult] {
        let currentDisplays = displayProvider.currentDisplays()
        displays = currentDisplays.isEmpty ? [Self.fallbackDisplay()] : currentDisplays

        let targets = enabledDisplays(from: displays)
        guard !targets.isEmpty else {
            throw AppContainerError.noDisplaysAvailable
        }

        let outputDirectory = Self.applicationSupportDirectory()
            .appendingPathComponent("Generated", isDirectory: true)
        let dependencies = try makeGenerationDependencies()
        let harness = WallpaperHarness(
            sourceProvider: dependencies.sourceProvider,
            aiProvider: dependencies.aiProvider,
            layoutPlanner: WordLayoutPlanner(),
            renderEngine: CoreGraphicsRenderEngine(),
            desktopSetter: dependencies.desktopSetter,
            historyStore: historyStore,
            outputDirectory: outputDirectory,
            compositionMode: dependencies.compositionMode,
            settings: settings
        )
        let coordinator = DisplayCoordinator(
            displayProvider: StaticDisplayProvider(displays: targets),
            harness: harness
        )
        let results = await coordinator.runOnce(settings: settings)
        let failed = results.first { $0.state != .succeeded }

        if let failed {
            throw AppContainerError.mockGenerationFailed(
                failed.errorDescription
                    ?? failed.harnessResult?.record.failureReason
                    ?? "Mock generation failed for \(failed.display.friendlyName)."
            )
        }

        let harnessResults = results.compactMap(\.harnessResult)
        lastGeneratedWallpaperURLs = harnessResults.compactMap(\.record.finalImageURL)
        lastErrorMessage = "Generated \(harnessResults.count) wallpaper(s) with \(providerMode.title)."

        return harnessResults
    }

    private func makeGenerationDependencies() throws -> GenerationDependencies {
        switch providerMode {
        case .mockPreview:
            return GenerationDependencies(
                sourceProvider: MockSourceProvider(),
                aiProvider: MockPreviewProvider(),
                desktopSetter: LoggingDesktopWallpaperSetter(),
                compositionMode: .cleanSourceImage
            )
        case .realProvider:
            let config = try makeProviderConfig(from: providerSettings)
            let provider = OpenAICompatibleProvider(config: config, secretStore: secretStore)
            let unsplashAccessKey = providerSettings.unsplashAccessKey
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !unsplashAccessKey.isEmpty else {
                throw AppContainerError.missingUnsplashAccessKey
            }

            return GenerationDependencies(
                sourceProvider: UnsplashSource(
                    accessKey: unsplashAccessKey
                ),
                aiProvider: provider,
                desktopSetter: NSWorkspaceDesktopWallpaperSetter(),
                compositionMode: .cleanSourceImage
            )
        }
    }

    private func makeProviderConfig(from draft: ProviderSettingsDraft) throws -> ProviderConfig {
        guard
            let baseURL = URL(string: draft.baseURL),
            let scheme = baseURL.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            !(baseURL.host ?? "").isEmpty
        else {
            throw AppContainerError.invalidBaseURL
        }

        return try ProviderConfig(
            id: "default",
            name: "Default",
            baseURL: baseURL,
            model: draft.model.trimmingCharacters(in: .whitespacesAndNewlines),
            secretRef: Self.providerSecretRef,
            additionalHeaders: try Self.parseHeaders(draft.additionalHeaders),
            capabilities: [.vision, .structuredOutput]
        )
    }

    private func persistProviderSettings(_ draft: ProviderSettingsDraft) throws -> ProviderConfig {
        let config = try makeProviderConfig(from: draft)

        // API Key 写入 Keychain，不进入 UserDefaults 或 JSON 配置。
        if draft.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try secretStore.delete(Self.providerSecretRef)
        } else {
            try secretStore.write(draft.apiKey, for: Self.providerSecretRef)
        }
        if draft.unsplashAccessKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try secretStore.delete(Self.unsplashSecretRef)
        } else {
            try secretStore.write(draft.unsplashAccessKey, for: Self.unsplashSecretRef)
        }

        userDefaults.set(draft.baseURL, forKey: ProviderDefaults.baseURL)
        userDefaults.set(draft.model, forKey: ProviderDefaults.model)
        userDefaults.set(draft.additionalHeaders, forKey: ProviderDefaults.additionalHeaders)

        return config
    }

    private static func loadProviderSettings(
        userDefaults: UserDefaults,
        secretStore: any SecretStore
    ) -> ProviderSettingsLoadResult {
        var apiKey = ""
        var unsplashAccessKey = ""
        var secretLoadError: Error?
        do {
            apiKey = try secretStore.read(Self.providerSecretRef) ?? ""
            unsplashAccessKey = try secretStore.read(Self.unsplashSecretRef) ?? ""
            secretLoadError = nil
        } catch {
            secretLoadError = error
        }

        return ProviderSettingsLoadResult(
            draft: ProviderSettingsDraft(
                baseURL: userDefaults.string(forKey: ProviderDefaults.baseURL)
                    ?? ProviderSettingsDraft.default.baseURL,
                model: userDefaults.string(forKey: ProviderDefaults.model)
                    ?? ProviderSettingsDraft.default.model,
                apiKey: apiKey,
                additionalHeaders: userDefaults.string(forKey: ProviderDefaults.additionalHeaders)
                    ?? ProviderSettingsDraft.default.additionalHeaders,
                unsplashAccessKey: unsplashAccessKey
            ),
            error: secretLoadError
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

    private func enabledDisplays(from sourceDisplays: [DisplayTarget]) -> [DisplayTarget] {
        guard !settings.enabledDisplayIDs.isEmpty else {
            return sourceDisplays
        }

        return sourceDisplays.filter { settings.enabledDisplayIDs.contains($0.id) }
    }

    static func applicationSupportDirectory() -> URL {
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

    static func describe(_ error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }

        return String(describing: error)
    }

    private static func fallbackDisplay() -> DisplayTarget {
        DisplayTarget(
            id: "mock-display",
            frame: CoreRect(x: 0, y: 0, width: 1440, height: 900),
            pixelSize: PixelSize(width: 1440, height: 900),
            scale: 1,
            colorSpace: "sRGB",
            isMain: true,
            friendlyName: "Mock Display"
        )
    }
}

private enum ProviderDefaults {
    static let baseURL = "RuralWallpaper.Provider.BaseURL"
    static let model = "RuralWallpaper.Provider.Model"
    static let additionalHeaders = "RuralWallpaper.Provider.AdditionalHeaders"
}

private struct ProviderSettingsLoadResult {
    var draft: ProviderSettingsDraft
    var error: Error?
}

private struct DraftSecretStore: SecretStore {
    var secretRef: SecretRef
    var secret: String

    func read(_ ref: SecretRef) throws -> String? {
        ref == secretRef ? secret : nil
    }

    func write(_ value: String, for ref: SecretRef) throws {}

    func delete(_ ref: SecretRef) throws {}
}

private struct GenerationDependencies {
    var sourceProvider: any SourceProvider
    var aiProvider: any AIProvider
    var desktopSetter: any DesktopWallpaperSetter
    var compositionMode: WallpaperCompositionMode
}

private struct StaticDisplayProvider: DisplayProvider {
    var displays: [DisplayTarget]

    func currentDisplays() -> [DisplayTarget] {
        displays
    }
}

private final class LoggingDesktopWallpaperSetter: DesktopWallpaperSetter, @unchecked Sendable {
    func setWallpaper(fileURL: URL, for display: DisplayTarget) throws {
        print("Mock desktop setter would set \(fileURL.path) for \(display.friendlyName)")
    }
}
