import CoreGraphics
import Foundation
import ImageIO

public enum MockSourceProviderError: Error, Equatable, LocalizedError, Sendable {
    case invalidImageSize
    case contextCreationFailed
    case imageCreationFailed
    case pngEncodingFailed

    public var errorDescription: String? {
        switch self {
        case .invalidImageSize:
            "Mock source image size must be greater than zero."
        case .contextCreationFailed:
            "Mock source image context could not be created."
        case .imageCreationFailed:
            "Mock source image could not be created."
        case .pngEncodingFailed:
            "Mock source image could not be encoded as PNG."
        }
    }
}

public struct MockSourceProvider: SourceProvider {
    public let id = "mock-source"

    public init() {}

    public func makeSourceImage(
        for display: DisplayTarget,
        settings: AppSettings
    ) async throws -> SourceImage {
        let prompt = "Mock rural desktop wallpaper with calm sky, fields, and no text"

        return SourceImage(
            imageData: try Self.makeGradientPNG(pixelSize: display.pixelSize),
            attribution: .aiGenerated(
                AIGeneratedAttribution(
                    prompt: prompt,
                    providerID: id,
                    model: "mock-gradient"
                )
            ),
            prompt: prompt
        )
    }

    static func makeGradientPNG(pixelSize: PixelSize) throws -> Data {
        guard pixelSize.width > 0, pixelSize.height > 0 else {
            throw MockSourceProviderError.invalidImageSize
        }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: pixelSize.width,
            height: pixelSize.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw MockSourceProviderError.contextCreationFailed
        }

        let width = CGFloat(pixelSize.width)
        let height = CGFloat(pixelSize.height)
        drawSky(in: context, colorSpace: colorSpace, width: width, height: height)
        drawField(in: context, colorSpace: colorSpace, width: width, height: height)

        guard let image = context.makeImage() else {
            throw MockSourceProviderError.imageCreationFailed
        }

        let data = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                data,
                "public.png" as CFString,
                1,
                nil
            )
        else {
            throw MockSourceProviderError.pngEncodingFailed
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw MockSourceProviderError.pngEncodingFailed
        }

        return data as Data
    }

    private static func drawSky(
        in context: CGContext,
        colorSpace: CGColorSpace,
        width: CGFloat,
        height: CGFloat
    ) {
        let colors = [
            CGColor(red: 0.46, green: 0.63, blue: 0.80, alpha: 1),
            CGColor(red: 0.86, green: 0.76, blue: 0.56, alpha: 1)
        ] as CFArray
        let locations: [CGFloat] = [0, 1]
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations)

        if let gradient {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: width, y: height * 0.75),
                options: []
            )
        }
    }

    private static func drawField(
        in context: CGContext,
        colorSpace: CGColorSpace,
        width: CGFloat,
        height: CGFloat
    ) {
        let horizonY = height * 0.52
        context.setFillColor(CGColor(red: 0.25, green: 0.45, blue: 0.26, alpha: 1))
        context.fill(CGRect(x: 0, y: horizonY, width: width, height: height - horizonY))

        let fieldColors = [
            CGColor(red: 0.58, green: 0.54, blue: 0.28, alpha: 1),
            CGColor(red: 0.22, green: 0.36, blue: 0.19, alpha: 1)
        ] as CFArray
        let locations: [CGFloat] = [0, 1]
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: fieldColors, locations: locations) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: width * 0.2, y: horizonY),
                end: CGPoint(x: width * 0.8, y: height),
                options: []
            )
        }

        context.setFillColor(CGColor(red: 0.12, green: 0.22, blue: 0.14, alpha: 0.22))
        for index in 0..<8 {
            let y = horizonY + CGFloat(index) * (height - horizonY) / 8
            context.fill(CGRect(x: 0, y: y, width: width, height: 2))
        }
    }
}
