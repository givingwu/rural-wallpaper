import Foundation

public enum LocalImageFileSourceError: Error, Equatable, LocalizedError, Sendable {
    case imageFileMissing(URL)

    public var errorDescription: String? {
        switch self {
        case .imageFileMissing(let url):
            return "Selected image file does not exist: \(url.path)"
        }
    }
}

public struct LocalImageFileSource: SourceProvider {
    public static let defaultID = "local-image"

    public let id = Self.defaultID
    public var imageURL: URL
    public var workspaceDirectory: URL

    public init(imageURL: URL, workspaceDirectory: URL) {
        self.imageURL = imageURL
        self.workspaceDirectory = workspaceDirectory
    }

    public func makeSourceImage(for display: DisplayTarget, settings: AppSettings) async throws -> SourceImage {
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw LocalImageFileSourceError.imageFileMissing(imageURL)
        }

        try FileManager.default.createDirectory(
            at: workspaceDirectory,
            withIntermediateDirectories: true
        )

        let copiedURL = workspaceDirectory
            .appendingPathComponent("\(safeFileComponent(display.id))-\(UUID().uuidString)")
            .appendingPathExtension(imageURL.pathExtension.isEmpty ? "png" : imageURL.pathExtension)
        try FileManager.default.copyItem(at: imageURL, to: copiedURL)
        let data = try Data(contentsOf: copiedURL)

        return SourceImage(
            imageData: data,
            attribution: .localDesktop(
                LocalDesktopAttribution(
                    originalURL: imageURL,
                    localFileURL: copiedURL
                )
            ),
            prompt: "Selected local image"
        )
    }

    private func safeFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let result = String(scalars)
        return result.isEmpty ? "display" : result
    }
}
