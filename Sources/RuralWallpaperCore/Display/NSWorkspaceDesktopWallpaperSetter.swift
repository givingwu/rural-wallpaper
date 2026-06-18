#if canImport(AppKit)
import AppKit

public enum DesktopWallpaperError: Error, Equatable, Sendable {
    case displayNotFound(displayID: String, friendlyName: String)
}

extension DesktopWallpaperError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .displayNotFound(let displayID, let friendlyName):
            return "No NSScreen matched display '\(friendlyName)' with id '\(displayID)'."
        }
    }
}

public struct NSWorkspaceDesktopWallpaperSetter: DesktopWallpaperSetter {
    public init() {}

    public func setWallpaper(fileURL: URL, for display: DisplayTarget) throws {
        try DisplayMainThread.sync {
            guard let screen = Self.screen(matching: display) else {
                throw DesktopWallpaperError.displayNotFound(
                    displayID: display.id,
                    friendlyName: display.friendlyName
                )
            }

            try NSWorkspace.shared.setDesktopImageURL(fileURL, for: screen, options: [:])
        }
    }

    private static func screen(matching display: DisplayTarget) -> NSScreen? {
        NSScreen.screens.enumerated().first { index, screen in
            NSScreenDisplayProvider.displayID(for: screen, index: index) == display.id
        }?.element
    }
}
#endif
