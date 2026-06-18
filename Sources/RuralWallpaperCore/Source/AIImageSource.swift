import CoreGraphics
import Foundation

public struct AIImageSource: SourceProvider {
    public static let defaultID = "ai-image"

    public let id: String

    private let provider: any AIProvider
    private let providerID: String
    private let model: String
    private let seedProvider: @Sendable (DisplayTarget) -> String

    public init(
        id: String = AIImageSource.defaultID,
        provider: any AIProvider,
        providerID: String,
        model: String,
        seedProvider: @escaping @Sendable (DisplayTarget) -> String = AIImageSource.defaultSeed(for:)
    ) {
        self.id = id
        self.provider = provider
        self.providerID = providerID
        self.model = model
        self.seedProvider = seedProvider
    }

    public func makeSourceImage(
        for display: DisplayTarget,
        settings: AppSettings
    ) async throws -> SourceImage {
        let prompt = makePrompt(for: display, settings: settings)
        let size = CGSize(
            width: display.pixelSize.width,
            height: display.pixelSize.height
        )
        let generatedImage = try await provider.generateImage(prompt: prompt, size: size)

        return SourceImage(
            imageData: generatedImage.data,
            attribution: .aiGenerated(
                AIGeneratedAttribution(
                    prompt: prompt,
                    providerID: providerID,
                    model: model
                )
            ),
            prompt: prompt
        )
    }

    private func makePrompt(for display: DisplayTarget, settings: AppSettings) -> String {
        let themes = settings.preferredThemes.isEmpty
            ? "rural, nature, calm"
            : settings.preferredThemes.joined(separator: ", ")
        let pixelSize = "\(display.pixelSize.width)x\(display.pixelSize.height)"
        let seed = seedProvider(display)

        return """
        Create a quiet desktop wallpaper with no text.
        Theme preferences: \(themes).
        Display pixel size: \(pixelSize).
        Use this per-display seed to avoid repeated screens: \(seed).
        Favor calm rural atmosphere, natural light, and generous negative space for later word placement.
        """
    }

    public static func defaultSeed(for display: DisplayTarget) -> String {
        "\(display.id)-\(display.pixelSize.width)x\(display.pixelSize.height)"
    }
}
