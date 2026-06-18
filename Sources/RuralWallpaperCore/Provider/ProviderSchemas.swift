import Foundation

public struct GeneratedSourceImage: Codable, Equatable, Sendable {
    public var data: Data
    public var prompt: String
    public var revisedPrompt: String?
    public var sourceURL: URL?

    public init(
        data: Data,
        prompt: String,
        revisedPrompt: String? = nil,
        sourceURL: URL? = nil
    ) {
        self.data = data
        self.prompt = prompt
        self.revisedPrompt = revisedPrompt
        self.sourceURL = sourceURL
    }
}

public struct WordExtractionResponse: Codable, Equatable, Sendable {
    public var words: [VocabularyItem]

    public init(words: [VocabularyItem]) {
        self.words = words
    }
}

public struct ImageGenerationResponse: Codable, Equatable, Sendable {
    public var data: [ImageGenerationOutput]

    public init(data: [ImageGenerationOutput]) {
        self.data = data
    }
}

public struct ImageGenerationOutput: Codable, Equatable, Sendable {
    public var b64JSON: String?
    public var url: URL?
    public var revisedPrompt: String?

    public init(
        b64JSON: String? = nil,
        url: URL? = nil,
        revisedPrompt: String? = nil
    ) {
        self.b64JSON = b64JSON
        self.url = url
        self.revisedPrompt = revisedPrompt
    }

    private enum CodingKeys: String, CodingKey {
        case b64JSON = "b64_json"
        case url
        case revisedPrompt = "revised_prompt"
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
