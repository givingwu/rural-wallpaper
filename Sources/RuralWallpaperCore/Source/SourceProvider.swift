import Foundation

public protocol SourceProvider: Sendable {
    var id: String { get }
    func makeSourceImage(for display: DisplayTarget, settings: AppSettings) async throws -> SourceImage
}

public struct SourceImage: Sendable, Equatable {
    public var imageData: Data
    public var attribution: SourceAttribution
    public var prompt: String?

    public init(imageData: Data, attribution: SourceAttribution, prompt: String? = nil) {
        self.imageData = imageData
        self.attribution = attribution
        self.prompt = prompt
    }
}
