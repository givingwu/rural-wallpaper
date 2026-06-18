import Foundation

public protocol DesktopWallpaperSetter: Sendable {
    func setWallpaper(fileURL: URL, for display: DisplayTarget) throws
}
