#if canImport(AppKit)
import AppKit
#endif
import Foundation

public enum CurrentDesktopSourceError: Error, Equatable, LocalizedError, Sendable {
    case missingWallpaperURL
    case wallpaperFileMissing(URL)

    public var errorDescription: String? {
        switch self {
        case .missingWallpaperURL:
            return "Current desktop wallpaper URL could not be found."
        case .wallpaperFileMissing(let url):
            return "Current desktop wallpaper file no longer exists: \(url.path)"
        }
    }
}

public struct CurrentDesktopSource: SourceProvider {
    public static let defaultID = "current-desktop"

    public let id = Self.defaultID
    public var workspaceDirectory: URL
    private let resolver: @Sendable (DisplayTarget) throws -> URL?

    public init(
        workspaceDirectory: URL,
        resolver: @escaping @Sendable (DisplayTarget) throws -> URL? = Self.defaultResolver
    ) {
        self.workspaceDirectory = workspaceDirectory
        self.resolver = resolver
    }

    public func makeSourceImage(for display: DisplayTarget, settings: AppSettings) async throws -> SourceImage {
        guard let originalURL = try resolver(display) else {
            throw CurrentDesktopSourceError.missingWallpaperURL
        }
        let resolvedURL: URL
        let prompt: String
        if FileManager.default.fileExists(atPath: originalURL.path) {
            resolvedURL = originalURL
            prompt = "Current desktop wallpaper"
        } else if let fallbackURL = newestImageCandidate(in: originalURL.deletingLastPathComponent()) {
            resolvedURL = fallbackURL
            prompt = "Current desktop wallpaper fallback: \(fallbackURL.lastPathComponent)"
        } else {
            throw CurrentDesktopSourceError.wallpaperFileMissing(originalURL)
        }

        try FileManager.default.createDirectory(
            at: workspaceDirectory,
            withIntermediateDirectories: true
        )

        let copiedURL = workspaceDirectory
            .appendingPathComponent("\(safeFileComponent(display.id))-\(UUID().uuidString)")
            .appendingPathExtension(resolvedURL.pathExtension.isEmpty ? "png" : resolvedURL.pathExtension)
        try FileManager.default.copyItem(at: resolvedURL, to: copiedURL)
        let data = try Data(contentsOf: copiedURL)

        return SourceImage(
            imageData: data,
            attribution: .localDesktop(
                LocalDesktopAttribution(
                    originalURL: resolvedURL,
                    localFileURL: copiedURL
                )
            ),
            prompt: prompt
        )
    }

    public static func defaultResolver(display: DisplayTarget) throws -> URL? {
        #if canImport(AppKit)
        return DisplayMainThread.sync {
            guard let screen = NSScreen.screens.enumerated().first(where: { index, screen in
                NSScreenDisplayProvider.displayID(for: screen, index: index) == display.id
            })?.element else {
                return nil
            }

            return NSWorkspace.shared.desktopImageURL(for: screen)
        }
        #else
        return nil
        #endif
    }

    private func safeFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let result = String(scalars)
        return result.isEmpty ? "display" : result
    }

    private func newestImageCandidate(in directoryURL: URL) -> URL? {
        let supportedExtensions: Set<String> = [
            "heic",
            "heif",
            "jpg",
            "jpeg",
            "png",
            "tif",
            "tiff",
            "webp"
        ]
        let keys: [URLResourceKey] = [
            .contentModificationDateKey,
            .isRegularFileKey
        ]
        guard let candidates = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return candidates
            .compactMap { url -> (url: URL, modifiedAt: Date)? in
                let fileExtension = url.pathExtension.lowercased()
                guard supportedExtensions.contains(fileExtension),
                      FileManager.default.isReadableFile(atPath: url.path) else {
                    return nil
                }

                let values = try? url.resourceValues(forKeys: Set(keys))
                guard values?.isRegularFile == true else {
                    return nil
                }

                return (url, values?.contentModificationDate ?? .distantPast)
            }
            .sorted { lhs, rhs in
                if lhs.modifiedAt == rhs.modifiedAt {
                    return lhs.url.path < rhs.url.path
                }
                return lhs.modifiedAt > rhs.modifiedAt
            }
            .first?
            .url
    }
}
