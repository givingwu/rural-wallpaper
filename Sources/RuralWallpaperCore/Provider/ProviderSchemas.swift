import Foundation

public struct WordExtractionResponse: Codable, Equatable, Sendable {
    public var words: [VocabularyItem]

    public init(words: [VocabularyItem]) {
        self.words = words
    }
}

public struct ImageAnalysisResponse: Codable, Equatable, Sendable {
    public var analysis: ImageAnalysis

    public init(analysis: ImageAnalysis) {
        self.analysis = analysis
    }
}

public struct EvaluationResponse: Codable, Equatable, Sendable {
    public var result: EvaluationResult

    public init(result: EvaluationResult) {
        self.result = result
    }
}
