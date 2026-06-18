import CoreGraphics
import Foundation
import XCTest
@testable import RuralWallpaperCore

final class SourceProviderTests: XCTestCase {
    func testAIImageSourceCallsProviderGenerateImageWithPromptAndDisplaySize() async throws {
        let imageData = Data("ai-image".utf8)
        let aiProvider = MockAIProvider(
            generatedImage: GeneratedSourceImage(
                data: imageData,
                prompt: "provider prompt",
                revisedPrompt: "revised prompt"
            )
        )
        let source = AIImageSource(
            provider: aiProvider,
            providerID: "openai-compatible",
            model: "image-model",
            seedProvider: { display in "seed-\(display.id)" }
        )
        let settings = AppSettings(
            autoUpdateEnabled: false,
            refreshIntervalHours: 24,
            maxBackgroundAttempts: 3,
            maxLayoutCandidates: 5,
            minimumScore: 0.75,
            historyLimitPerDisplay: 30,
            preferredThemes: ["rural", "mist"],
            enabledDisplayIDs: []
        )

        let result = try await source.makeSourceImage(
            for: makeDisplayTarget(pixelSize: PixelSize(width: 2880, height: 1800)),
            settings: settings
        )

        XCTAssertEqual(result.imageData, imageData)
        XCTAssertEqual(aiProvider.generateImageCalls.count, 1)

        let call = try XCTUnwrap(aiProvider.generateImageCalls.first)
        XCTAssertEqual(call.size, CGSize(width: 2880, height: 1800))
        XCTAssertTrue(call.prompt.contains("rural"))
        XCTAssertTrue(call.prompt.contains("mist"))
        XCTAssertTrue(call.prompt.contains("2880x1800"))
        XCTAssertTrue(call.prompt.localizedCaseInsensitiveContains("quiet desktop wallpaper"))
        XCTAssertTrue(call.prompt.localizedCaseInsensitiveContains("no text"))
        XCTAssertTrue(call.prompt.contains("seed-display-1"))

        XCTAssertEqual(result.prompt, call.prompt)
        XCTAssertEqual(
            result.attribution,
            .aiGenerated(
                AIGeneratedAttribution(
                    prompt: call.prompt,
                    providerID: "openai-compatible",
                    model: "image-model"
                )
            )
        )
    }

    func testAIImageSourcePropagatesMissingImageGenerationCapability() async throws {
        let aiProvider = MockAIProvider(error: ProviderError.missingCapability(.imageGeneration))
        let source = AIImageSource(
            provider: aiProvider,
            providerID: "vision-only",
            model: "vision-model",
            seedProvider: { _ in "stable-seed" }
        )

        do {
            _ = try await source.makeSourceImage(for: makeDisplayTarget(), settings: .default)
            XCTFail("Expected missing image generation capability to throw")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .missingCapability(.imageGeneration))
        }
    }

    func testUnsplashSourceBuildsRequestsDownloadsImageAndReturnsAttribution() async throws {
        let imageData = Data("unsplash-image".utf8)
        let httpClient = MockSourceHTTPClient(responses: [
            HTTPResponse(statusCode: 200, data: unsplashPhotoJSON()),
            HTTPResponse(statusCode: 204, data: Data()),
            HTTPResponse(statusCode: 200, data: imageData)
        ])
        let source = UnsplashSource(
            accessKey: "test-access-key",
            httpClient: httpClient,
            baseURL: URL(string: "https://api.unsplash.test")!
        )

        let result = try await source.makeSourceImage(
            for: makeDisplayTarget(pixelSize: PixelSize(width: 3024, height: 1964)),
            settings: AppSettings.default
        )

        XCTAssertEqual(result.imageData, imageData)
        XCTAssertNil(result.prompt)
        XCTAssertEqual(httpClient.requests.count, 3)

        let photoRequest = try XCTUnwrap(httpClient.requests.first)
        XCTAssertEqual(photoRequest.method, "GET")
        XCTAssertEqual(photoRequest.url.scheme, "https")
        XCTAssertEqual(photoRequest.url.host, "api.unsplash.test")
        XCTAssertEqual(photoRequest.url.path, "/photos/random")
        XCTAssertEqual(photoRequest.headers["Authorization"], "Client-ID test-access-key")
        XCTAssertEqual(queryItem("orientation", in: photoRequest.url), "landscape")
        XCTAssertEqual(queryItem("query", in: photoRequest.url), "rural nature calm")

        let trackingRequest = httpClient.requests[1]
        XCTAssertEqual(trackingRequest.method, "GET")
        XCTAssertEqual(
            trackingRequest.url,
            URL(string: "https://api.unsplash.test/photos/photo-123/download?ixid=test")!
        )

        let imageRequest = httpClient.requests[2]
        XCTAssertEqual(imageRequest.method, "GET")
        XCTAssertEqual(imageRequest.url, URL(string: "https://images.unsplash.test/photo-123.jpg")!)

        XCTAssertEqual(
            result.attribution,
            .unsplash(
                UnsplashAttribution(
                    photoID: "photo-123",
                    authorName: "Jane Photographer",
                    authorURL: URL(string: "https://unsplash.test/@jane")!,
                    sourceURL: URL(string: "https://unsplash.test/photos/photo-123")!,
                    downloadLocation: URL(
                        string: "https://api.unsplash.test/photos/photo-123/download?ixid=test"
                    )!
                )
            )
        )
    }

    func testUnsplashSourceRequiresDownloadLocationBeforeDownloadingImage() async throws {
        let imageData = Data("unsplash-image".utf8)
        let httpClient = MockSourceHTTPClient(responses: [
            HTTPResponse(statusCode: 200, data: unsplashPhotoJSON(downloadLocation: nil)),
            HTTPResponse(statusCode: 200, data: imageData)
        ])
        let source = UnsplashSource(
            accessKey: "test-access-key",
            httpClient: httpClient,
            baseURL: URL(string: "https://api.unsplash.test")!
        )

        do {
            _ = try await source.makeSourceImage(
                for: makeDisplayTarget(),
                settings: AppSettings.default
            )
            XCTFail("Expected missing Unsplash download location to throw")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .invalidResponse)
        }

        XCTAssertEqual(httpClient.requests.count, 1)
        XCTAssertFalse(
            httpClient.requests.contains {
                $0.url == URL(string: "https://images.unsplash.test/photo-123.jpg")!
            }
        )
    }

    func testUnsplashSourceIsNotTheDefaultSource() {
        let aiSource = AIImageSource(
            provider: MockAIProvider(generatedImage: GeneratedSourceImage(data: Data(), prompt: "")),
            providerID: "openai-compatible",
            model: "image-model",
            seedProvider: { _ in "seed" }
        )
        let unsplashSource = UnsplashSource(
            accessKey: "test-access-key",
            httpClient: MockSourceHTTPClient(responses: []),
            baseURL: URL(string: "https://api.unsplash.test")!
        )

        XCTAssertEqual(aiSource.id, AIImageSource.defaultID)
        XCTAssertNotEqual(unsplashSource.id, AIImageSource.defaultID)
    }

    private func makeDisplayTarget(
        pixelSize: PixelSize = PixelSize(width: 2880, height: 1800)
    ) -> DisplayTarget {
        DisplayTarget(
            id: "display-1",
            frame: CoreRect(x: 0, y: 0, width: 1440, height: 900),
            pixelSize: pixelSize,
            scale: 2,
            colorSpace: "P3",
            isMain: true,
            friendlyName: "Built-in Display"
        )
    }

    private func unsplashPhotoJSON(
        downloadLocation: String? = "https://api.unsplash.test/photos/photo-123/download?ixid=test"
    ) -> Data {
        var links: [String: Any] = [
            "html": "https://unsplash.test/photos/photo-123"
        ]

        if let downloadLocation {
            links["download_location"] = downloadLocation
        }

        let object: [String: Any] = [
            "id": "photo-123",
            "urls": [
                "full": "https://images.unsplash.test/photo-123.jpg"
            ],
            "links": links,
            "user": [
                "name": "Jane Photographer",
                "links": [
                    "html": "https://unsplash.test/@jane"
                ]
            ]
        ]

        return try! JSONSerialization.data(withJSONObject: object)
    }

    private func queryItem(_ name: String, in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == name }?
            .value
    }
}

private final class MockAIProvider: AIProvider, @unchecked Sendable {
    private(set) var generateImageCalls: [(prompt: String, size: CGSize)] = []
    private let generatedImage: GeneratedSourceImage?
    private let error: Error?

    init(generatedImage: GeneratedSourceImage? = nil, error: Error? = nil) {
        self.generatedImage = generatedImage
        self.error = error
    }

    func generateImage(prompt: String, size: CGSize) async throws -> GeneratedSourceImage {
        generateImageCalls.append((prompt, size))

        if let error {
            throw error
        }

        return try XCTUnwrap(generatedImage)
    }

    func extractWords(from image: Data, countRange: ClosedRange<Int>) async throws -> [VocabularyItem] {
        throw UnexpectedMockCall()
    }

    func analyzeImage(_ image: Data, display: DisplayTarget) async throws -> ImageAnalysis {
        throw UnexpectedMockCall()
    }

    func evaluate(
        renderedImage: Data,
        plan: LayoutPlan,
        words: [VocabularyItem]
    ) async throws -> EvaluationResult {
        throw UnexpectedMockCall()
    }
}

private final class MockSourceHTTPClient: HTTPClient, @unchecked Sendable {
    private(set) var requests: [HTTPRequest] = []
    private var responses: [HTTPResponse]

    init(responses: [HTTPResponse]) {
        self.responses = responses
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(request)

        guard !responses.isEmpty else {
            throw UnexpectedMockCall()
        }

        return responses.removeFirst()
    }
}

private struct UnexpectedMockCall: Error {}
