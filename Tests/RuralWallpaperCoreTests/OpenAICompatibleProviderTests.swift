import CoreGraphics
import Foundation
import XCTest
@testable import RuralWallpaperCore

final class OpenAICompatibleProviderTests: XCTestCase {
    func testGenerateImageBuildsAuthorizedRequestFromSecretAndSafeHeaders() async throws {
        let secretStore = MockSecretStore([
            (SecretRef(service: "RuralWallpaperTests", account: "image"), "secret-from-store")
        ])
        let imageData = Data("generated-image".utf8)
        let httpClient = MockHTTPClient(responses: [
            HTTPResponse(
                statusCode: 200,
                data: imageGenerationResponseJSON(
                    base64Image: imageData.base64EncodedString(),
                    revisedPrompt: "A revised quiet rural wallpaper prompt."
                )
            )
        ])
        let provider = OpenAICompatibleProvider(
            config: try makeProviderConfig(
                baseURL: URL(string: "https://api.example.com/v1/")!,
                model: "image-model",
                secretAccount: "image",
                additionalHeaders: ["X-Provider-Org": "rural-tests"],
                capabilities: [.imageGeneration]
            ),
            secretStore: secretStore,
            httpClient: httpClient
        )

        let result = try await provider.generateImage(
            prompt: "A quiet farm at sunrise",
            size: CGSize(width: 1024, height: 768)
        )

        XCTAssertEqual(result.data, imageData)
        XCTAssertEqual(result.revisedPrompt, "A revised quiet rural wallpaper prompt.")

        let request = try XCTUnwrap(httpClient.requests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.url.absoluteString, "https://api.example.com/v1/images/generations")
        XCTAssertEqual(request.headers["Authorization"], "Bearer secret-from-store")
        XCTAssertEqual(request.headers["X-Provider-Org"], "rural-tests")
        XCTAssertEqual(request.headers["Content-Type"], "application/json")

        let body = try decodedJSONObject(from: request)
        XCTAssertEqual(body["model"] as? String, "image-model")
        XCTAssertEqual(body["prompt"] as? String, "A quiet farm at sunrise")
        XCTAssertEqual(body["size"] as? String, "1024x768")
    }

    func testExtractWordsJoinsBaseURLAndChatEndpointWhenEndpointHasLeadingSlash() async throws {
        let secretStore = MockSecretStore([
            (SecretRef(service: "RuralWallpaperTests", account: "vision"), "vision-secret")
        ])
        let httpClient = MockHTTPClient(responses: [
            HTTPResponse(
                statusCode: 200,
                data: try chatCompletionJSON(content: wordExtractionContentJSON())
            )
        ])
        let provider = OpenAICompatibleProvider(
            config: try makeProviderConfig(
                baseURL: URL(string: "https://api.example.com/openai")!,
                model: "vision-model",
                secretAccount: "vision",
                capabilities: [.vision]
            ),
            secretStore: secretStore,
            httpClient: httpClient
        )

        let words = try await provider.extractWords(from: Data("image".utf8), countRange: 3...5)

        XCTAssertEqual(words.map(\.word), ["meadow"])

        let request = try XCTUnwrap(httpClient.requests.first)
        XCTAssertEqual(request.url.absoluteString, "https://api.example.com/openai/chat/completions")
    }

    func testExtractWordsThrowsClearErrorWhenVisionCapabilityIsMissing() async throws {
        let secretStore = MockSecretStore([
            (SecretRef(service: "RuralWallpaperTests", account: "no-vision"), "secret")
        ])
        let httpClient = MockHTTPClient(responses: [])
        let provider = OpenAICompatibleProvider(
            config: try makeProviderConfig(
                model: "image-only-model",
                secretAccount: "no-vision",
                capabilities: [.imageGeneration]
            ),
            secretStore: secretStore,
            httpClient: httpClient
        )

        do {
            _ = try await provider.extractWords(from: Data("image".utf8), countRange: 3...5)
            XCTFail("Expected missing vision capability to throw")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .missingCapability(.vision))
            XCTAssertTrue(error.localizedDescription.lowercased().contains("vision"))
        }

        XCTAssertTrue(httpClient.requests.isEmpty)
    }

    func testExtractWordsReturnsInvalidResponseWhenJSONCannotBeParsed() async throws {
        let secretStore = MockSecretStore([
            (SecretRef(service: "RuralWallpaperTests", account: "vision"), "vision-secret")
        ])
        let httpClient = MockHTTPClient(responses: [
            HTTPResponse(statusCode: 200, data: Data("not-json".utf8))
        ])
        let provider = OpenAICompatibleProvider(
            config: try makeProviderConfig(
                model: "vision-model",
                secretAccount: "vision",
                capabilities: [.vision]
            ),
            secretStore: secretStore,
            httpClient: httpClient
        )

        do {
            _ = try await provider.extractWords(from: Data("image".utf8), countRange: 3...5)
            XCTFail("Expected invalid response to throw")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .invalidResponse)
        }
    }

    func testNonSuccessfulHTTPStatusThrowsProviderError() async throws {
        let secretStore = MockSecretStore([
            (SecretRef(service: "RuralWallpaperTests", account: "vision"), "vision-secret")
        ])
        let httpClient = MockHTTPClient(responses: [
            HTTPResponse(statusCode: 429, data: Data("rate limited".utf8))
        ])
        let provider = OpenAICompatibleProvider(
            config: try makeProviderConfig(
                model: "vision-model",
                secretAccount: "vision",
                capabilities: [.vision]
            ),
            secretStore: secretStore,
            httpClient: httpClient
        )

        do {
            _ = try await provider.extractWords(from: Data("image".utf8), countRange: 3...5)
            XCTFail("Expected HTTP status error to throw")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .httpStatus(429))
        }
    }

    func testAnalyzeImageDecodesWrappedImageAnalysisResponse() async throws {
        let secretStore = MockSecretStore([
            (SecretRef(service: "RuralWallpaperTests", account: "vision"), "vision-secret")
        ])
        let httpClient = MockHTTPClient(responses: [
            HTTPResponse(
                statusCode: 200,
                data: try chatCompletionJSON(content: wrappedImageAnalysisContentJSON())
            )
        ])
        let provider = OpenAICompatibleProvider(
            config: try makeProviderConfig(
                model: "vision-model",
                secretAccount: "vision",
                capabilities: [.vision]
            ),
            secretStore: secretStore,
            httpClient: httpClient
        )

        let analysis = try await provider.analyzeImage(
            Data("image".utf8),
            display: makeDisplayTarget()
        )

        XCTAssertEqual(analysis.summary, "Misty rural field")
        XCTAssertEqual(analysis.sceneHints, ["field", "mist"])
        XCTAssertEqual(analysis.depthHints, ["soft background ridge"])
        XCTAssertEqual(httpClient.requests.count, 1)
    }

    func testAnalyzeImageDecodesDirectImageAnalysisFallback() async throws {
        let secretStore = MockSecretStore([
            (SecretRef(service: "RuralWallpaperTests", account: "vision"), "vision-secret")
        ])
        let httpClient = MockHTTPClient(responses: [
            HTTPResponse(
                statusCode: 200,
                data: try chatCompletionJSON(content: directImageAnalysisContentJSON())
            )
        ])
        let provider = OpenAICompatibleProvider(
            config: try makeProviderConfig(
                model: "vision-model",
                secretAccount: "vision",
                capabilities: [.vision]
            ),
            secretStore: secretStore,
            httpClient: httpClient
        )

        let analysis = try await provider.analyzeImage(
            Data("image".utf8),
            display: makeDisplayTarget()
        )

        XCTAssertEqual(analysis.summary, "Direct rural field")
        XCTAssertEqual(analysis.notes, "direct fallback")
    }

    func testEvaluateDecodesWrappedEvaluationResponse() async throws {
        let secretStore = MockSecretStore([
            (SecretRef(service: "RuralWallpaperTests", account: "vision"), "vision-secret")
        ])
        let httpClient = MockHTTPClient(responses: [
            HTTPResponse(
                statusCode: 200,
                data: try chatCompletionJSON(content: wrappedEvaluationContentJSON())
            )
        ])
        let provider = OpenAICompatibleProvider(
            config: try makeProviderConfig(
                model: "vision-model",
                secretAccount: "vision",
                capabilities: [.vision]
            ),
            secretStore: secretStore,
            httpClient: httpClient
        )

        let result = try await provider.evaluate(
            renderedImage: Data("rendered".utf8),
            plan: makeLayoutPlan(),
            words: makeVocabularyItems()
        )

        XCTAssertEqual(result.readability, 0.91)
        XCTAssertEqual(result.notes, "wrapped evaluation")
        XCTAssertEqual(httpClient.requests.count, 1)
    }

    func testEvaluateDecodesDirectEvaluationResultFallback() async throws {
        let secretStore = MockSecretStore([
            (SecretRef(service: "RuralWallpaperTests", account: "vision"), "vision-secret")
        ])
        let httpClient = MockHTTPClient(responses: [
            HTTPResponse(
                statusCode: 200,
                data: try chatCompletionJSON(content: directEvaluationContentJSON())
            )
        ])
        let provider = OpenAICompatibleProvider(
            config: try makeProviderConfig(
                model: "vision-model",
                secretAccount: "vision",
                capabilities: [.vision]
            ),
            secretStore: secretStore,
            httpClient: httpClient
        )

        let result = try await provider.evaluate(
            renderedImage: Data("rendered".utf8),
            plan: makeLayoutPlan(),
            words: makeVocabularyItems()
        )

        XCTAssertEqual(result.wordRelevance, 0.88)
        XCTAssertEqual(result.notes, "direct evaluation")
    }

    func testAnalyzeImageMissingVisionCapabilityThrowsBeforeSendingHTTPRequest() async throws {
        let secretStore = MockSecretStore([
            (SecretRef(service: "RuralWallpaperTests", account: "image-only"), "secret")
        ])
        let httpClient = MockHTTPClient(responses: [])
        let provider = OpenAICompatibleProvider(
            config: try makeProviderConfig(
                model: "image-model",
                secretAccount: "image-only",
                capabilities: [.imageGeneration]
            ),
            secretStore: secretStore,
            httpClient: httpClient
        )

        do {
            _ = try await provider.analyzeImage(Data("image".utf8), display: makeDisplayTarget())
            XCTFail("Expected missing vision capability to throw")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .missingCapability(.vision))
        }

        XCTAssertTrue(httpClient.requests.isEmpty)
    }

    func testMissingSecretThrowsBeforeSendingHTTPRequest() async throws {
        let secretRef = SecretRef(service: "RuralWallpaperTests", account: "missing")
        let secretStore = MockSecretStore([])
        let httpClient = MockHTTPClient(responses: [])
        let provider = OpenAICompatibleProvider(
            config: try makeProviderConfig(
                model: "vision-model",
                secretAccount: secretRef.account,
                capabilities: [.vision]
            ),
            secretStore: secretStore,
            httpClient: httpClient
        )

        do {
            _ = try await provider.extractWords(from: Data("image".utf8), countRange: 3...5)
            XCTFail("Expected missing secret to throw")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .missingSecret(secretRef))
        }

        XCTAssertTrue(httpClient.requests.isEmpty)
    }

    private func makeProviderConfig(
        baseURL: URL = URL(string: "https://api.example.com/v1")!,
        model: String,
        secretAccount: String,
        additionalHeaders: [String: String] = [:],
        capabilities: ProviderCapability
    ) throws -> ProviderConfig {
        try ProviderConfig(
            id: "test-provider",
            name: "Test Provider",
            baseURL: baseURL,
            model: model,
            secretRef: SecretRef(service: "RuralWallpaperTests", account: secretAccount),
            additionalHeaders: additionalHeaders,
            capabilities: capabilities
        )
    }

    private func decodedJSONObject(from request: HTTPRequest) throws -> [String: Any] {
        let body = try XCTUnwrap(request.body)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    private func imageGenerationResponseJSON(
        base64Image: String,
        revisedPrompt: String
    ) -> Data {
        let object: [String: Any] = [
            "data": [
                [
                    "b64_json": base64Image,
                    "revised_prompt": revisedPrompt
                ]
            ]
        ]

        return try! JSONSerialization.data(withJSONObject: object)
    }

    private func chatCompletionJSON(content: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "choices": [
                [
                    "message": [
                        "content": content
                    ]
                ]
            ]
        ])
    }

    private func wordExtractionContentJSON() throws -> String {
        let data = try JSONSerialization.data(withJSONObject: [
            "words": [
                [
                    "word": "meadow",
                    "partOfSpeech": "noun",
                    "zhDefinition": "草地",
                    "example": "A quiet meadow stretches beyond the cottage.",
                    "difficulty": 2,
                    "sourceReason": "Open rural grassland in the scene."
                ]
            ]
        ])

        return String(data: data, encoding: .utf8)!
    }

    private func wrappedImageAnalysisContentJSON() throws -> String {
        try jsonString([
            "analysis": imageAnalysisObject(
                summary: "Misty rural field",
                notes: "wrapped response"
            )
        ])
    }

    private func directImageAnalysisContentJSON() throws -> String {
        try jsonString(
            imageAnalysisObject(
                summary: "Direct rural field",
                notes: "direct fallback"
            )
        )
    }

    private func imageAnalysisObject(summary: String, notes: String) -> [String: Any] {
        [
            "summary": summary,
            "sceneHints": ["field", "mist"],
            "safeTextRegions": [],
            "depthHints": ["soft background ridge"],
            "notes": notes
        ]
    }

    private func wrappedEvaluationContentJSON() throws -> String {
        try jsonString([
            "result": evaluationObject(
                readability: 0.91,
                wordRelevance: 0.86,
                notes: "wrapped evaluation"
            )
        ])
    }

    private func directEvaluationContentJSON() throws -> String {
        try jsonString(
            evaluationObject(
                readability: 0.84,
                wordRelevance: 0.88,
                notes: "direct evaluation"
            )
        )
    }

    private func evaluationObject(
        readability: Double,
        wordRelevance: Double,
        notes: String
    ) -> [String: Any] {
        [
            "readability": readability,
            "sceneFit": 0.87,
            "depthBelievability": 0.78,
            "desktopCalmness": 0.9,
            "wordRelevance": wordRelevance,
            "noBadOcclusion": 0.96,
            "textCorrectness": 1.0,
            "notes": notes
        ]
    }

    private func makeDisplayTarget() -> DisplayTarget {
        DisplayTarget(
            id: "display-1",
            frame: CoreRect(x: 0, y: 0, width: 1440, height: 900),
            pixelSize: PixelSize(width: 2880, height: 1800),
            scale: 2,
            colorSpace: "P3",
            isMain: true,
            friendlyName: "Built-in Display"
        )
    }

    private func makeLayoutPlan() -> LayoutPlan {
        LayoutPlan(
            displayID: "display-1",
            wordPlacements: [
                LayoutWordPlacement(
                    word: "meadow",
                    rect: CoreRect(x: 100, y: 120, width: 220, height: 72),
                    baseline: CorePoint(x: 110, y: 170),
                    fontSize: 48,
                    depth: 0.4,
                    opacity: 0.92
                )
            ],
            depthMode: .depthAware,
            score: 0.86
        )
    }

    private func makeVocabularyItems() -> [VocabularyItem] {
        [
            VocabularyItem(
                word: "meadow",
                partOfSpeech: "noun",
                zhDefinition: "草地",
                example: "A quiet meadow stretches beyond the cottage.",
                difficulty: 2,
                sourceReason: "Open rural grassland in the scene."
            )
        ]
    }

    private func jsonString(_ object: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object)
        return String(data: data, encoding: .utf8)!
    }
}

private final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    private(set) var requests: [HTTPRequest] = []
    private var responses: [HTTPResponse]

    init(responses: [HTTPResponse]) {
        self.responses = responses
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(request)

        guard !responses.isEmpty else {
            throw MockHTTPClientError.missingResponse
        }

        return responses.removeFirst()
    }
}

private enum MockHTTPClientError: Error {
    case missingResponse
}

private final class MockSecretStore: SecretStore, @unchecked Sendable {
    private var values: [String: String]

    init(_ values: [(SecretRef, String)]) {
        self.values = Dictionary(uniqueKeysWithValues: values.map { (Self.key(for: $0.0), $0.1) })
    }

    func read(_ ref: SecretRef) throws -> String? {
        values[Self.key(for: ref)]
    }

    func write(_ value: String, for ref: SecretRef) throws {
        values[Self.key(for: ref)] = value
    }

    func delete(_ ref: SecretRef) throws {
        values.removeValue(forKey: Self.key(for: ref))
    }

    private static func key(for ref: SecretRef) -> String {
        "\(ref.service)#\(ref.account)"
    }
}
