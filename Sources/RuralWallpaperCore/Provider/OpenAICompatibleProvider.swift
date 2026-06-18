import CoreGraphics
import Foundation

public protocol AIProvider: Sendable {
    func generateImage(prompt: String, size: CGSize) async throws -> GeneratedSourceImage
    func extractWords(from image: Data, countRange: ClosedRange<Int>) async throws -> [VocabularyItem]
    func analyzeImage(_ image: Data, display: DisplayTarget) async throws -> ImageAnalysis
    func evaluate(
        renderedImage: Data,
        plan: LayoutPlan,
        words: [VocabularyItem]
    ) async throws -> EvaluationResult
}

public enum ProviderError: Error, Equatable, Sendable {
    case missingCapability(ProviderCapability)
    case missingSecret(SecretRef)
    case invalidConfiguration(String)
    case httpStatus(Int)
    case invalidResponse
}

extension ProviderError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingCapability(let capability):
            "Provider is missing required capability: \(capability.providerErrorName)."
        case .missingSecret(let ref):
            "Provider secret is missing for \(ref.service)/\(ref.account)."
        case .invalidConfiguration(let message):
            "Provider configuration is invalid: \(message)."
        case .httpStatus(let statusCode):
            "Provider request failed with HTTP status \(statusCode)."
        case .invalidResponse:
            "Provider returned an invalid response."
        }
    }
}

public struct OpenAICompatibleProvider: AIProvider {
    public let config: ProviderConfig
    private let secretStore: any SecretStore
    private let httpClient: any HTTPClient

    public init(
        config: ProviderConfig,
        secretStore: any SecretStore,
        httpClient: any HTTPClient = URLSessionHTTPClient()
    ) {
        self.config = config
        self.secretStore = secretStore
        self.httpClient = httpClient
    }

    public func generateImage(prompt: String, size: CGSize) async throws -> GeneratedSourceImage {
        try requireCapability(.imageGeneration)

        let request = ImageGenerationRequest(
            model: config.model,
            prompt: prompt,
            size: "\(Int(size.width.rounded()))x\(Int(size.height.rounded()))",
            responseFormat: "b64_json"
        )
        let response = try await sendJSON(request, endpoint: "/images/generations")
        let decoded: ImageGenerationResponse = try decodeJSON(response.data)

        guard
            let firstImage = decoded.data.first,
            let encodedImage = firstImage.b64JSON,
            let imageData = Data(base64Encoded: encodedImage)
        else {
            throw ProviderError.invalidResponse
        }

        return GeneratedSourceImage(
            data: imageData,
            prompt: prompt,
            revisedPrompt: firstImage.revisedPrompt,
            sourceURL: firstImage.url
        )
    }

    public func extractWords(
        from image: Data,
        countRange: ClosedRange<Int>
    ) async throws -> [VocabularyItem] {
        try requireCapability(.vision)

        let response = try await sendVisionRequest(
            image: image,
            prompt: wordExtractionPrompt(countRange: countRange)
        )
        let decoded: WordExtractionResponse = try decodeStructuredChatResponse(from: response.data)

        return decoded.words
    }

    public func analyzeImage(_ image: Data, display: DisplayTarget) async throws -> ImageAnalysis {
        try requireCapability(.vision)

        let displayJSON = try encodeJSONString(display)
        let response = try await sendVisionRequest(
            image: image,
            prompt: imageAnalysisPrompt(displayJSON: displayJSON)
        )

        if let wrapped: ImageAnalysisResponse = try? decodeStructuredChatResponse(from: response.data) {
            return wrapped.analysis
        }

        if let analysis: ImageAnalysis = try? decodeStructuredChatResponse(from: response.data) {
            return analysis
        }

        throw ProviderError.invalidResponse
    }

    public func evaluate(
        renderedImage: Data,
        plan: LayoutPlan,
        words: [VocabularyItem]
    ) async throws -> EvaluationResult {
        try requireCapability(.vision)

        let layoutJSON = try encodeJSONString(plan)
        let wordsJSON = try encodeJSONString(words)
        let response = try await sendVisionRequest(
            image: renderedImage,
            prompt: evaluationPrompt(layoutJSON: layoutJSON, wordsJSON: wordsJSON)
        )

        if let wrapped: EvaluationResponse = try? decodeStructuredChatResponse(from: response.data) {
            return wrapped.result
        }

        if let result: EvaluationResult = try? decodeStructuredChatResponse(from: response.data) {
            return result
        }

        throw ProviderError.invalidResponse
    }

    private func requireCapability(_ capability: ProviderCapability) throws {
        guard config.capabilities.contains(capability) else {
            throw ProviderError.missingCapability(capability)
        }
    }

    private func sendVisionRequest(image: Data, prompt: String) async throws -> HTTPResponse {
        let request = ChatCompletionRequest(
            model: config.model,
            messages: [
                ChatMessage(
                    role: "user",
                    content: [
                        .text(prompt),
                        .image(data: image)
                    ]
                )
            ],
            responseFormat: config.capabilities.contains(.structuredOutput)
                ? ChatResponseFormat(type: "json_object")
                : nil
        )

        return try await sendJSON(request, endpoint: "/chat/completions")
    }

    private func sendJSON<T: Encodable>(_ body: T, endpoint: String) async throws -> HTTPResponse {
        let request = HTTPRequest(
            url: try endpointURL(endpoint),
            method: "POST",
            headers: try requestHeaders(),
            body: try encodeJSON(body)
        )
        let response = try await httpClient.send(request)

        guard (200...299).contains(response.statusCode) else {
            throw ProviderError.httpStatus(response.statusCode)
        }

        return response
    }

    private func requestHeaders() throws -> [String: String] {
        guard let secret = try secretStore.read(config.secretRef), !secret.isEmpty else {
            throw ProviderError.missingSecret(config.secretRef)
        }

        var headers = [
            "Content-Type": "application/json"
        ]

        for (key, value) in config.additionalHeaders {
            headers[key] = value
        }

        headers["Authorization"] = "Bearer \(secret)"

        return headers
    }

    private func endpointURL(_ endpoint: String) throws -> URL {
        guard var components = URLComponents(url: config.baseURL, resolvingAgainstBaseURL: false) else {
            throw ProviderError.invalidConfiguration("baseURL is not a valid URL")
        }

        let basePath = components.path.trimmingSlashes()
        let endpointPath = endpoint.trimmingSlashes()
        let joinedPath = [basePath, endpointPath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")

        components.path = joinedPath.isEmpty ? "/" : "/\(joinedPath)"
        components.query = nil
        components.fragment = nil

        guard let url = components.url else {
            throw ProviderError.invalidConfiguration("baseURL cannot be joined with endpoint")
        }

        return url
    }

    private func encodeJSON<T: Encodable>(_ value: T) throws -> Data {
        do {
            return try JSONEncoder().encode(value)
        } catch {
            throw ProviderError.invalidConfiguration("request body could not be encoded")
        }
    }

    private func encodeJSONString<T: Encodable>(_ value: T) throws -> String {
        let data = try encodeJSON(value)

        guard let string = String(data: data, encoding: .utf8) else {
            throw ProviderError.invalidConfiguration("request body could not be converted to UTF-8")
        }

        return string
    }

    private func decodeJSON<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ProviderError.invalidResponse
        }
    }

    private func decodeStructuredChatResponse<T: Decodable>(from data: Data) throws -> T {
        if let direct: T = try? JSONDecoder().decode(T.self, from: data) {
            return direct
        }

        guard
            let chatResponse = try? JSONDecoder().decode(ChatCompletionResponse.self, from: data),
            let content = chatResponse.choices.first?.message.content,
            let contentData = content.data(using: .utf8),
            let decoded = try? JSONDecoder().decode(T.self, from: contentData)
        else {
            throw ProviderError.invalidResponse
        }

        return decoded
    }

    private func wordExtractionPrompt(countRange: ClosedRange<Int>) -> String {
        """
        请从这张图片中提取 \(countRange.lowerBound)-\(countRange.upperBound) 个适合作为桌面学习内容的英文词汇。只返回 JSON，格式为：
        {"words":[{"word":"meadow","partOfSpeech":"noun","zhDefinition":"草地","example":"A quiet meadow stretches beyond the cottage.","difficulty":2,"sourceReason":"画面中有开阔草地。"}]}
        """
    }

    private func imageAnalysisPrompt(displayJSON: String) -> String {
        """
        请分析这张壁纸图片，结合显示器信息判断画面主体、景深和适合放置英文单词的安全区域。显示器信息：
        \(displayJSON)
        只返回 JSON，格式为：
        {"analysis":{"summary":"...","sceneHints":["..."],"safeTextRegions":[],"depthHints":["..."],"notes":"..."}}
        """
    }

    private func evaluationPrompt(layoutJSON: String, wordsJSON: String) -> String {
        """
        请评估这张已经渲染英文单词的壁纸是否适合设为桌面。排版方案：
        \(layoutJSON)
        词汇：
        \(wordsJSON)
        只返回 JSON，格式为：
        {"result":{"readability":0.9,"sceneFit":0.9,"depthBelievability":0.9,"desktopCalmness":0.9,"wordRelevance":0.9,"noBadOcclusion":0.95,"textCorrectness":1.0,"notes":"..."}}
        """
    }
}

private struct ImageGenerationRequest: Encodable {
    var model: String
    var prompt: String
    var size: String
    var responseFormat: String

    private enum CodingKeys: String, CodingKey {
        case model
        case prompt
        case size
        case responseFormat = "response_format"
    }
}

private struct ChatCompletionRequest: Encodable {
    var model: String
    var messages: [ChatMessage]
    var responseFormat: ChatResponseFormat?

    private enum CodingKeys: String, CodingKey {
        case model
        case messages
        case responseFormat = "response_format"
    }
}

private struct ChatMessage: Encodable {
    var role: String
    var content: [ChatMessageContent]
}

private struct ChatMessageContent: Encodable {
    var type: String
    var text: String?
    var imageURL: ChatImageURL?

    static func text(_ value: String) -> ChatMessageContent {
        ChatMessageContent(type: "text", text: value, imageURL: nil)
    }

    static func image(data: Data) -> ChatMessageContent {
        ChatMessageContent(
            type: "image_url",
            text: nil,
            imageURL: ChatImageURL(url: "data:image/png;base64,\(data.base64EncodedString())")
        )
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
    }
}

private struct ChatImageURL: Encodable {
    var url: String
}

private struct ChatResponseFormat: Encodable {
    var type: String
}

private struct ChatCompletionResponse: Decodable {
    var choices: [ChatChoice]
}

private struct ChatChoice: Decodable {
    var message: ChatCompletionMessage
}

private struct ChatCompletionMessage: Decodable {
    var content: String?
}

private extension ProviderCapability {
    var providerErrorName: String {
        var names: [String] = []

        if contains(.vision) {
            names.append("vision")
        }

        if contains(.imageGeneration) {
            names.append("imageGeneration")
        }

        if contains(.structuredOutput) {
            names.append("structuredOutput")
        }

        return names.isEmpty ? "unknown" : names.joined(separator: ", ")
    }
}

private extension String {
    func trimmingSlashes() -> String {
        trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
