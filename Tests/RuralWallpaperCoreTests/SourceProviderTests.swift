import Foundation
import XCTest
@testable import RuralWallpaperCore

final class SourceProviderTests: XCTestCase {
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

    func testUnsplashSourceUsesDefaultWallpaperSourceID() {
        let unsplashSource = UnsplashSource(
            accessKey: "test-access-key",
            httpClient: MockSourceHTTPClient(responses: []),
            baseURL: URL(string: "https://api.unsplash.test")!
        )

        XCTAssertEqual(unsplashSource.id, UnsplashSource.defaultID)
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
