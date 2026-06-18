#if canImport(AppKit)
import AppKit

public struct NSScreenDisplayProvider: DisplayProvider {
    public init() {}

    public func currentDisplays() -> [DisplayTarget] {
        NSScreen.screens.enumerated().map { index, screen in
            Self.makeDisplayTarget(for: screen, index: index)
        }
    }

    static func makeDisplayTarget(for screen: NSScreen, index: Int) -> DisplayTarget {
        let frame = screen.frame
        let scale = Double(screen.backingScaleFactor)
        let pixelWidth = Int((frame.width * screen.backingScaleFactor).rounded())
        let pixelHeight = Int((frame.height * screen.backingScaleFactor).rounded())

        return DisplayTarget(
            id: displayID(for: screen, index: index),
            frame: CoreRect(
                x: Double(frame.origin.x),
                y: Double(frame.origin.y),
                width: Double(frame.width),
                height: Double(frame.height)
            ),
            pixelSize: PixelSize(width: pixelWidth, height: pixelHeight),
            scale: scale,
            colorSpace: colorSpaceName(for: screen),
            isMain: isMain(screen),
            friendlyName: friendlyName(for: screen, frame: frame)
        )
    }

    static func displayID(for screen: NSScreen, index: Int) -> String {
        if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return "nsscreen-\(screenNumber.uint64Value)"
        }

        let frame = screen.frame
        let roundedFrame = [
            Int(frame.origin.x.rounded()),
            Int(frame.origin.y.rounded()),
            Int(frame.width.rounded()),
            Int(frame.height.rounded())
        ]
        .map(String.init)
        .joined(separator: "-")

        return "nsscreen-\(index)-\(roundedFrame)"
    }

    private static func isMain(_ screen: NSScreen) -> Bool {
        guard let mainScreen = NSScreen.main else {
            return false
        }

        return screen === mainScreen
    }

    private static func colorSpaceName(for screen: NSScreen) -> String {
        if let localizedName = screen.colorSpace?.localizedName, !localizedName.isEmpty {
            return localizedName
        }

        if let colorSpaceName = screen.colorSpace?.cgColorSpace?.name {
            let rawName = colorSpaceName as String
            if !rawName.isEmpty {
                return rawName
            }
        }

        if let rawName = screen.colorSpace?.description, !rawName.isEmpty {
            return rawName
        }

        return "Unknown"
    }

    private static func friendlyName(for screen: NSScreen, frame: NSRect) -> String {
        let localizedName = screen.localizedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !localizedName.isEmpty {
            return localizedName
        }

        let width = Int(frame.width.rounded())
        let height = Int(frame.height.rounded())
        let originX = Int(frame.origin.x.rounded())
        let originY = Int(frame.origin.y.rounded())
        return "Display \(width)x\(height) @ \(originX),\(originY)"
    }
}
#endif
