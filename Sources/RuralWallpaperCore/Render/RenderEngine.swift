import Foundation

public protocol RenderEngine: Sendable {
    func render(
        background: Data,
        plan: LayoutPlan,
        display: DisplayTarget
    ) throws -> RenderedWallpaper
}

public struct RenderedWallpaper: Equatable, Sendable {
    public let pngData: Data
    public let displayID: String
    public let layoutPlan: LayoutPlan
    public let pixelSize: PixelSize

    public init(
        pngData: Data,
        displayID: String,
        layoutPlan: LayoutPlan,
        pixelSize: PixelSize
    ) {
        self.pngData = pngData
        self.displayID = displayID
        self.layoutPlan = layoutPlan
        self.pixelSize = pixelSize
    }
}

public enum RenderError: Error, Equatable, LocalizedError, Sendable {
    case invalidBackgroundImage
    case invalidDisplaySize
    case invalidLayout
    case pngEncodingFailed

    public var errorDescription: String? {
        switch self {
        case .invalidBackgroundImage:
            return "Background image data could not be decoded."
        case .invalidDisplaySize:
            return "Display target pixel size must be greater than zero."
        case .invalidLayout:
            return "Layout text bounds exceed the placement rect or display canvas."
        case .pngEncodingFailed:
            return "Rendered wallpaper could not be encoded as PNG."
        }
    }
}
