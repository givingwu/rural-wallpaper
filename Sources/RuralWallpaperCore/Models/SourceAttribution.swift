import Foundation

public struct AIGeneratedAttribution: Codable, Equatable, Sendable {
    public var prompt: String
    public var providerID: String
    public var model: String

    public init(prompt: String, providerID: String, model: String) {
        self.prompt = prompt
        self.providerID = providerID
        self.model = model
    }
}

public struct UnsplashAttribution: Codable, Equatable, Sendable {
    public var photoID: String
    public var authorName: String
    public var authorURL: URL?
    public var sourceURL: URL?
    public var downloadLocation: URL?

    public init(
        photoID: String,
        authorName: String,
        authorURL: URL?,
        sourceURL: URL?,
        downloadLocation: URL?
    ) {
        self.photoID = photoID
        self.authorName = authorName
        self.authorURL = authorURL
        self.sourceURL = sourceURL
        self.downloadLocation = downloadLocation
    }
}

public struct LocalDesktopAttribution: Codable, Equatable, Sendable {
    public var originalURL: URL
    public var localFileURL: URL

    public init(originalURL: URL, localFileURL: URL) {
        self.originalURL = originalURL
        self.localFileURL = localFileURL
    }
}

public enum SourceAttribution: Codable, Equatable, Sendable {
    case aiGenerated(AIGeneratedAttribution)
    case unsplash(UnsplashAttribution)
    case localDesktop(LocalDesktopAttribution)

    public var localFileURL: URL? {
        switch self {
        case .aiGenerated, .unsplash:
            return nil
        case .localDesktop(let attribution):
            return attribution.localFileURL
        }
    }
}
