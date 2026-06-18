public struct EvaluationResult: Codable, Equatable, Sendable {
    public var readability: Double
    public var sceneFit: Double
    public var depthBelievability: Double
    public var desktopCalmness: Double
    public var wordRelevance: Double
    public var noBadOcclusion: Double
    public var textCorrectness: Double
    public var notes: String

    public init(
        readability: Double,
        sceneFit: Double,
        depthBelievability: Double,
        desktopCalmness: Double,
        wordRelevance: Double,
        noBadOcclusion: Double,
        textCorrectness: Double,
        notes: String
    ) {
        self.readability = readability
        self.sceneFit = sceneFit
        self.depthBelievability = depthBelievability
        self.desktopCalmness = desktopCalmness
        self.wordRelevance = wordRelevance
        self.noBadOcclusion = noBadOcclusion
        self.textCorrectness = textCorrectness
        self.notes = notes
    }

    public var averageScore: Double {
        let scores = [
            readability,
            sceneFit,
            depthBelievability,
            desktopCalmness,
            wordRelevance,
            noBadOcclusion,
            textCorrectness
        ]

        return scores.reduce(0, +) / Double(scores.count)
    }

    public func passes(threshold: Double) -> Bool {
        averageScore >= threshold
            && textCorrectness >= 0.95
            && noBadOcclusion >= 0.75
    }
}
