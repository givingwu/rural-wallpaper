public struct ImageAnalysis: Codable, Equatable, Sendable {
    public var summary: String
    public var sceneHints: [String]
    public var safeTextRegions: [CoreRect]
    public var subjectRects: [CoreRect]
    public var lowDetailRects: [CoreRect]
    public var horizonLines: [Double]
    public var brightnessHotspots: [CoreRect]
    public var maskConfidence: Double
    public var depthHints: [String]
    public var notes: String

    public init(
        summary: String,
        sceneHints: [String] = [],
        safeTextRegions: [CoreRect] = [],
        subjectRects: [CoreRect] = [],
        lowDetailRects: [CoreRect] = [],
        horizonLines: [Double] = [],
        brightnessHotspots: [CoreRect] = [],
        maskConfidence: Double = 0,
        depthHints: [String] = [],
        notes: String = ""
    ) {
        self.summary = summary
        self.sceneHints = sceneHints
        self.safeTextRegions = safeTextRegions
        self.subjectRects = subjectRects
        self.lowDetailRects = lowDetailRects
        self.horizonLines = horizonLines
        self.brightnessHotspots = brightnessHotspots
        self.maskConfidence = maskConfidence
        self.depthHints = depthHints
        self.notes = notes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.summary = try container.decode(String.self, forKey: .summary)
        self.sceneHints = try container.decodeIfPresent([String].self, forKey: .sceneHints) ?? []
        self.safeTextRegions = try container.decodeIfPresent([CoreRect].self, forKey: .safeTextRegions) ?? []
        self.subjectRects = try container.decodeIfPresent([CoreRect].self, forKey: .subjectRects) ?? []
        self.lowDetailRects = try container.decodeIfPresent([CoreRect].self, forKey: .lowDetailRects) ?? []
        self.horizonLines = try container.decodeIfPresent([Double].self, forKey: .horizonLines) ?? []
        self.brightnessHotspots = try container.decodeIfPresent([CoreRect].self, forKey: .brightnessHotspots) ?? []
        self.maskConfidence = try container.decodeIfPresent(Double.self, forKey: .maskConfidence) ?? 0
        self.depthHints = try container.decodeIfPresent([String].self, forKey: .depthHints) ?? []
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(summary, forKey: .summary)
        try container.encode(sceneHints, forKey: .sceneHints)
        try container.encode(safeTextRegions, forKey: .safeTextRegions)
        try container.encode(subjectRects, forKey: .subjectRects)
        try container.encode(lowDetailRects, forKey: .lowDetailRects)
        try container.encode(horizonLines, forKey: .horizonLines)
        try container.encode(brightnessHotspots, forKey: .brightnessHotspots)
        try container.encode(maskConfidence, forKey: .maskConfidence)
        try container.encode(depthHints, forKey: .depthHints)
        try container.encode(notes, forKey: .notes)
    }

    private enum CodingKeys: String, CodingKey {
        case summary
        case sceneHints
        case safeTextRegions
        case subjectRects
        case lowDetailRects
        case horizonLines
        case brightnessHotspots
        case maskConfidence
        case depthHints
        case notes
    }
}
