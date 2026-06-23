import Foundation
import RuralWallpaperCore
import SwiftUI

struct ProviderSettingsDraft: Equatable {
    var cliCommand: CLIWordCommand
    var baseURL: String
    var model: String
    var apiKey: String
    var additionalHeaders: String
    var unsplashAccessKey: String

    init(
        cliCommand: CLIWordCommand = .codex,
        baseURL: String,
        model: String,
        apiKey: String,
        additionalHeaders: String,
        unsplashAccessKey: String = ""
    ) {
        self.cliCommand = cliCommand
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.additionalHeaders = additionalHeaders
        self.unsplashAccessKey = unsplashAccessKey
    }

    static let `default` = ProviderSettingsDraft(
        cliCommand: .codex,
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
    case noPreviewAvailable
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
        case .noPreviewAvailable:
            "No wallpaper preview is available to apply."
        case .mockGenerationFailed(let message):
            message
        }
    }
}

struct GlassWallpaperPreview: Equatable, Identifiable {
    let id: UUID
    let display: DisplayTarget
    let sourceImageURL: URL
    let previewImageURL: URL
    let words: [VocabularyItem]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        display: DisplayTarget,
        sourceImageURL: URL,
        previewImageURL: URL,
        words: [VocabularyItem],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.display = display
        self.sourceImageURL = sourceImageURL
        self.previewImageURL = previewImageURL
        self.words = words
        self.createdAt = createdAt
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
    @Published private(set) var activeGlassPreview: GlassWallpaperPreview?
    @Published private(set) var generationProgressMessage = "Ready"
    @Published var lastErrorMessage: String?

    private let settingsStore: any SettingsStore
    private let secretStore: any SecretStore
    private let historyStore: any HistoryStore
    private let displayProvider: any DisplayProvider
    private let userDefaults: UserDefaults
    private let supportDirectory: URL
    private let previewSourceProvider: any SourceProvider
    private let previewWordProviderOverride: (any ImageFileWordProvider)?
    private let previewDesktopSetter: any DesktopWallpaperSetter
    private let logger: AppLogger

    var logFileURL: URL {
        logger.logFileURL
    }

    var selectedPreviewDisplay: DisplayTarget? {
        previewDisplay(from: displays)
    }

    init(
        settingsStore: any SettingsStore = UserDefaultsSettingsStore(),
        secretStore: any SecretStore = KeychainSecretStore(),
        displayProvider: any DisplayProvider = NSScreenDisplayProvider(),
        historyStore: (any HistoryStore)? = nil,
        userDefaults: UserDefaults = .standard,
        supportDirectory: URL? = nil,
        previewSourceProvider: (any SourceProvider)? = nil,
        previewWordProvider: (any ImageFileWordProvider)? = nil,
        previewDesktopSetter: (any DesktopWallpaperSetter)? = nil,
        logger: AppLogger? = nil
    ) {
        self.settingsStore = settingsStore
        self.secretStore = secretStore
        self.displayProvider = displayProvider
        self.userDefaults = userDefaults
        let resolvedSupportDirectory = supportDirectory ?? Self.applicationSupportDirectory()
        self.supportDirectory = resolvedSupportDirectory
        self.previewSourceProvider = previewSourceProvider ?? CurrentDesktopSource(
            workspaceDirectory: resolvedSupportDirectory
                .appendingPathComponent("CurrentDesktop", isDirectory: true)
        )
        self.previewWordProviderOverride = previewWordProvider
        self.previewDesktopSetter = previewDesktopSetter ?? NSWorkspaceDesktopWallpaperSetter()
        self.logger = logger ?? AppLogger(
            logFileURL: resolvedSupportDirectory.appendingPathComponent("rural-wallpaper.log")
        )

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
            storageURL: resolvedSupportDirectory
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
        logger.info("display.reload.begin")
        displays = displayProvider.currentDisplays()
        logger.info("display.reload.done count=\(displays.count)")
    }

    func selectPreviewDisplay(id displayID: String) {
        guard displays.contains(where: { $0.id == displayID }) else {
            logger.info("display.select.ignored missing=\(displayID)")
            return
        }

        var nextSettings = settings
        nextSettings.selectedPreviewDisplayID = displayID
        saveGenerationSettings(nextSettings)
        logger.info("display.select.done id=\(displayID)")
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

    @discardableResult
    func generateGlassPreview() async throws -> GlassWallpaperPreview {
        try await generateGlassPreview(using: previewSourceProvider)
    }

    @discardableResult
    func generateGlassPreview(from imageURL: URL) async throws -> GlassWallpaperPreview {
        let source = LocalImageFileSource(
            imageURL: imageURL,
            workspaceDirectory: supportDirectory
                .appendingPathComponent("SelectedImages", isDirectory: true)
        )
        return try await generateGlassPreview(using: source)
    }

    @discardableResult
    private func generateGlassPreview(using sourceProvider: any SourceProvider) async throws -> GlassWallpaperPreview {
        logger.info("preview.begin")
        generationProgressMessage = "Preparing display"
        do {
            let currentDisplays = displayProvider.currentDisplays()
            displays = currentDisplays.isEmpty ? [Self.fallbackDisplay()] : currentDisplays
            guard let display = previewDisplay(from: displays) else {
                throw AppContainerError.noDisplaysAvailable
            }
            logger.info("display.selected id=\(display.id) name=\(display.friendlyName) pixels=\(display.pixelSize.width)x\(display.pixelSize.height)")
            try Task.checkCancellation()

            let previewDirectory = supportDirectory.appendingPathComponent("Previews", isDirectory: true)
            try FileManager.default.createDirectory(
                at: previewDirectory,
                withIntermediateDirectories: true
            )
            logger.info("preview.directory path=\(previewDirectory.path)")

            generationProgressMessage = "Reading wallpaper"
            logger.info("source.begin provider=\(sourceProvider.id)")
            let source = try await sourceProvider.makeSourceImage(
                for: display,
                settings: settings
            )
            try Task.checkCancellation()
            let sourceURL = try source.attribution.localFileURL
                ?? writePreviewData(
                    source.imageData,
                    directory: previewDirectory,
                    display: display,
                    prefix: "source",
                    fileExtension: "png"
                )
            let sourcePrompt = source.prompt
                .map { " prompt=\($0.replacingOccurrences(of: "\n", with: " "))" }
                ?? ""
            logger.info("source.done bytes=\(source.imageData.count) path=\(sourceURL.path)\(sourcePrompt)")

            generationProgressMessage = "Extracting words"
            let wordProvider = currentPreviewWordProvider()
            logger.info("words.begin provider=\(type(of: wordProvider)) image=\(sourceURL.path)")
            let words = try await wordProvider.extractWords(from: sourceURL)
            try Task.checkCancellation()
            guard (3...5).contains(words.count) else {
                throw CLIWordProviderError.invalidWordCount(words.count)
            }
            logger.info("words.done count=\(words.count) words=\(words.map(\.word).joined(separator: ","))")

            generationProgressMessage = "Rendering preview"
            logger.info("render.begin mode=glass")
            let rendered = try CoreGraphicsRenderEngine().renderGlassOverlay(
                background: source.imageData,
                words: words,
                display: display
            )
            try Task.checkCancellation()
            let previewURL = try writePreviewData(
                rendered.pngData,
                directory: previewDirectory,
                display: display,
                prefix: "glass-preview",
                fileExtension: "png"
            )
            logger.info("render.done bytes=\(rendered.pngData.count) path=\(previewURL.path)")

            let preview = GlassWallpaperPreview(
                display: display,
                sourceImageURL: sourceURL,
                previewImageURL: previewURL,
                words: words
            )

            activeGlassPreview = preview
            lastGeneratedWallpaperURLs = [previewURL]
            lastErrorMessage = "Preview generated with \(words.count) word(s)."
            generationProgressMessage = "Ready"
            logger.info("preview.done id=\(preview.id.uuidString)")
            return preview
        } catch is CancellationError {
            generationProgressMessage = "Cancelled"
            lastErrorMessage = "Generation cancelled."
            logger.info("preview.cancelled")
            throw CancellationError()
        } catch {
            generationProgressMessage = "Failed"
            logger.error("preview.failed error=\(Self.describe(error))")
            throw error
        }
    }

    func applyGlassPreview(_ preview: GlassWallpaperPreview? = nil) throws {
        logger.info("apply.begin")
        guard let preview = preview ?? activeGlassPreview else {
            logger.error("apply.failed error=\(AppContainerError.noPreviewAvailable.localizedDescription)")
            throw AppContainerError.noPreviewAvailable
        }

        do {
            try previewDesktopSetter.setWallpaper(fileURL: preview.previewImageURL, for: preview.display)
            lastErrorMessage = "Applied preview to \(preview.display.friendlyName)."
            logger.info("apply.done path=\(preview.previewImageURL.path) display=\(preview.display.id)")
        } catch {
            logger.error("apply.failed error=\(Self.describe(error))")
            throw error
        }
    }

    func runWallpaperFlow() async throws -> [WallpaperHarnessResult] {
        let currentDisplays = displayProvider.currentDisplays()
        displays = currentDisplays.isEmpty ? [Self.fallbackDisplay()] : currentDisplays

        let targets = enabledDisplays(from: displays)
        guard !targets.isEmpty else {
            throw AppContainerError.noDisplaysAvailable
        }

        let outputDirectory = supportDirectory
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

        userDefaults.set(draft.cliCommand.rawValue, forKey: ProviderDefaults.cliCommand)
        userDefaults.set(draft.baseURL, forKey: ProviderDefaults.baseURL)
        userDefaults.set(draft.model, forKey: ProviderDefaults.model)
        userDefaults.set(draft.additionalHeaders, forKey: ProviderDefaults.additionalHeaders)

        return config
    }

    private func currentPreviewWordProvider() -> any ImageFileWordProvider {
        previewWordProviderOverride ?? CLIWordProvider(
            command: providerSettings.cliCommand,
            logHandler: { [logger] message in
                logger.info(message)
            }
        )
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
                cliCommand: CLIWordCommand(
                    rawValue: userDefaults.string(forKey: ProviderDefaults.cliCommand) ?? ""
                ) ?? ProviderSettingsDraft.default.cliCommand,
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

    private func previewDisplay(from sourceDisplays: [DisplayTarget]) -> DisplayTarget? {
        if let selectedDisplayID = settings.selectedPreviewDisplayID,
           let selected = sourceDisplays.first(where: { $0.id == selectedDisplayID }) {
            return selected
        }

        return sourceDisplays.first(where: \.isMain) ?? sourceDisplays.first
    }

    private func writePreviewData(
        _ data: Data,
        directory: URL,
        display: DisplayTarget,
        prefix: String,
        fileExtension: String
    ) throws -> URL {
        let fileURL = directory
            .appendingPathComponent(
                "\(prefix)-\(Self.safeFileComponent(display.id))-\(UUID().uuidString)"
            )
            .appendingPathExtension(fileExtension)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
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

    private static func safeFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let result = String(scalars)
        return result.isEmpty ? "display" : result
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
    static let cliCommand = "RuralWallpaper.Provider.CLICommand"
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
