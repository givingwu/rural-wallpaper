public struct ImageAnalysis: Codable, Equatable, Sendable {
    public var summary: String
    public var sceneHints: [String]
    public var safeTextRegions: [CoreRect]
    public var depthHints: [String]
    public var notes: String

    public init(
        summary: String,
        sceneHints: [String] = [],
        safeTextRegions: [CoreRect] = [],
        depthHints: [String] = [],
        notes: String = ""
    ) {
        self.summary = summary
        self.sceneHints = sceneHints
        self.safeTextRegions = safeTextRegions
        self.depthHints = depthHints
        self.notes = notes
    }
}
