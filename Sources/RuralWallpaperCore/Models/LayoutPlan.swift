public enum LayoutDepthMode: String, Codable, Equatable, Sendable {
    case flat
    case depthAware
    case foregroundAware
}

public struct LayoutWordPlacement: Codable, Equatable, Sendable {
    public var word: String
    public var rect: CoreRect
    public var baseline: CorePoint
    public var fontSize: Double
    public var depth: Double
    public var opacity: Double

    public init(
        word: String,
        rect: CoreRect,
        baseline: CorePoint,
        fontSize: Double,
        depth: Double,
        opacity: Double
    ) {
        self.word = word
        self.rect = rect
        self.baseline = baseline
        self.fontSize = fontSize
        self.depth = depth
        self.opacity = opacity
    }
}

public struct LayoutPlan: Codable, Equatable, Sendable {
    public var displayID: String
    public var wordPlacements: [LayoutWordPlacement]
    public var depthMode: LayoutDepthMode
    public var score: Double

    public init(
        displayID: String,
        wordPlacements: [LayoutWordPlacement],
        depthMode: LayoutDepthMode,
        score: Double
    ) {
        self.displayID = displayID
        self.wordPlacements = wordPlacements
        self.depthMode = depthMode
        self.score = score
    }
}
