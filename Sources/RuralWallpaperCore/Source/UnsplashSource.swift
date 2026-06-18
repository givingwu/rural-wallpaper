import Foundation

public struct UnsplashSource: SourceProvider {
    public static let defaultID = "unsplash"

    public let id: String

    private let accessKey: String
    private let httpClient: any HTTPClient
    private let baseURL: URL

    public init(
        id: String = UnsplashSource.defaultID,
        accessKey: String,
        httpClient: any HTTPClient,
        baseURL: URL = URL(string: "https://api.unsplash.com")!
    ) {
        self.id = id
        self.accessKey = accessKey
        self.httpClient = httpClient
        self.baseURL = baseURL
    }

    public func makeSourceImage(
        for display: DisplayTarget,
        settings: AppSettings
    ) async throws -> SourceImage {
        let photoResponse = try await send(request: randomPhotoRequest(settings: settings))
        let photo: UnsplashPhotoResponse = try decode(photoResponse.data)

        guard let downloadLocation = photo.links.downloadLocation else {
            throw ProviderError.invalidResponse
        }
        _ = try await send(request: authorizedGET(downloadLocation))

        guard let imageURL = photo.urls.full else {
            throw ProviderError.invalidResponse
        }

        let imageResponse = try await send(request: HTTPRequest(url: imageURL, method: "GET"))

        return SourceImage(
            imageData: imageResponse.data,
            attribution: .unsplash(
                UnsplashAttribution(
                    photoID: photo.id,
                    authorName: photo.user.name,
                    authorURL: photo.user.links.html,
                    sourceURL: photo.links.html,
                    downloadLocation: downloadLocation
                )
            )
        )
    }

    private func randomPhotoRequest(settings: AppSettings) throws -> HTTPRequest {
        var components = try components(for: "/photos/random")
        components.queryItems = [
            URLQueryItem(name: "query", value: query(from: settings)),
            URLQueryItem(name: "orientation", value: "landscape")
        ]

        guard let url = components.url else {
            throw ProviderError.invalidConfiguration("Unsplash random photo URL could not be built")
        }

        return authorizedGET(url)
    }

    private func query(from settings: AppSettings) -> String {
        guard !settings.preferredThemes.isEmpty else {
            return "rural nature calm"
        }

        return settings.preferredThemes.joined(separator: " ")
    }

    private func components(for endpoint: String) throws -> URLComponents {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw ProviderError.invalidConfiguration("Unsplash baseURL is not a valid URL")
        }

        let basePath = components.path.trimmingSlashes()
        let endpointPath = endpoint.trimmingSlashes()
        let joinedPath = [basePath, endpointPath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")

        components.path = joinedPath.isEmpty ? "/" : "/\(joinedPath)"
        components.query = nil
        components.fragment = nil

        return components
    }

    private func authorizedGET(_ url: URL) -> HTTPRequest {
        HTTPRequest(
            url: url,
            method: "GET",
            headers: [
                "Authorization": "Client-ID \(accessKey)"
            ]
        )
    }

    private func send(request: HTTPRequest) async throws -> HTTPResponse {
        let response = try await httpClient.send(request)

        guard (200...299).contains(response.statusCode) else {
            throw ProviderError.httpStatus(response.statusCode)
        }

        return response
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ProviderError.invalidResponse
        }
    }
}

private struct UnsplashPhotoResponse: Decodable {
    var id: String
    var urls: UnsplashPhotoURLs
    var links: UnsplashPhotoLinks
    var user: UnsplashUser
}

private struct UnsplashPhotoURLs: Decodable {
    var full: URL?
}

private struct UnsplashPhotoLinks: Decodable {
    var html: URL?
    var downloadLocation: URL?

    private enum CodingKeys: String, CodingKey {
        case html
        case downloadLocation = "download_location"
    }
}

private struct UnsplashUser: Decodable {
    var name: String
    var links: UnsplashUserLinks
}

private struct UnsplashUserLinks: Decodable {
    var html: URL?
}

private extension String {
    func trimmingSlashes() -> String {
        trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
