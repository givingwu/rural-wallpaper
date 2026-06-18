import Foundation

public struct GeneratedWallpaper: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public var finalImageURL: URL?
    public var sourceImageURL: URL?
    public var display: DisplayTarget
    public var words: [VocabularyItem]
    public var layout: LayoutPlan?
    public var evaluation: EvaluationResult?
    public var attribution: SourceAttribution?
    public var providerID: String
    public var createdAt: Date
    public var failureReason: String?

    public init(
        id: String = UUID().uuidString,
        finalImageURL: URL?,
        sourceImageURL: URL?,
        display: DisplayTarget,
        words: [VocabularyItem],
        layout: LayoutPlan?,
        evaluation: EvaluationResult?,
        attribution: SourceAttribution?,
        providerID: String,
        createdAt: Date = Date(),
        failureReason: String? = nil
    ) {
        self.id = id
        self.finalImageURL = finalImageURL
        self.sourceImageURL = sourceImageURL
        self.display = display
        self.words = words
        self.layout = layout
        self.evaluation = evaluation
        self.attribution = attribution
        self.providerID = providerID
        self.createdAt = createdAt
        self.failureReason = failureReason
    }
}
