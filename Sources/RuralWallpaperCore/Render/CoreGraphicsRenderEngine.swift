import AppKit
import Foundation
import ImageIO

public struct CoreGraphicsRenderEngine: RenderEngine {
    public init() {}

    public func render(
        background: Data,
        plan: LayoutPlan,
        display: DisplayTarget
    ) throws -> RenderedWallpaper {
        let backgroundImage = try decodeImage(from: background)
        let canvasWidth = display.pixelSize.width
        let canvasHeight = display.pixelSize.height

        guard canvasWidth > 0, canvasHeight > 0 else {
            throw RenderError.invalidDisplaySize
        }

        let context = try makeBitmapContext(width: canvasWidth, height: canvasHeight)
        let canvas = CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)

        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(canvas)
        drawScaleToFill(image: backgroundImage, in: canvas, context: context)
        drawWords(plan.wordPlacements, context: context)

        guard let renderedImage = context.makeImage() else {
            throw RenderError.pngEncodingFailed
        }

        let bitmap = NSBitmapImageRep(cgImage: renderedImage)
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw RenderError.pngEncodingFailed
        }

        return RenderedWallpaper(
            pngData: pngData,
            displayID: display.id,
            layoutPlan: plan,
            pixelSize: display.pixelSize
        )
    }

    private func decodeImage(from data: Data) throws -> CGImage {
        guard
            let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            throw RenderError.invalidBackgroundImage
        }

        return image
    }

    private func makeBitmapContext(width: Int, height: Int) throws -> CGContext {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
            ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue
            | CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw RenderError.pngEncodingFailed
        }

        context.interpolationQuality = .high
        context.setShouldAntialias(true)
        return context
    }

    private func drawScaleToFill(
        image: CGImage,
        in canvas: CGRect,
        context: CGContext
    ) {
        let imageSize = CGSize(width: image.width, height: image.height)
        let scale = max(
            canvas.width / imageSize.width,
            canvas.height / imageSize.height
        )
        let scaledSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        let drawRect = CGRect(
            x: canvas.midX - scaledSize.width / 2,
            y: canvas.midY - scaledSize.height / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )

        context.draw(image, in: drawRect)
    }

    private func drawWords(
        _ placements: [LayoutWordPlacement],
        context: CGContext
    ) {
        guard !placements.isEmpty else { return }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        defer {
            NSGraphicsContext.restoreGraphicsState()
        }

        for placement in placements {
            drawWord(placement)
        }
    }

    private func drawWord(_ placement: LayoutWordPlacement) {
        let fontSize = CGFloat(max(placement.fontSize, 1))
        let opacity = CGFloat(placement.opacity.clamped(to: 0...1))
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.32 * opacity)
        shadow.shadowBlurRadius = max(2, fontSize * 0.07)
        shadow.shadowOffset = CGSize(width: 0, height: 2)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(white: 0.98, alpha: opacity),
            .shadow: shadow
        ]
        let attributedWord = NSAttributedString(
            string: placement.word,
            attributes: attributes
        )
        let drawPoint = CGPoint(
            x: placement.baseline.x,
            y: placement.baseline.y - Double(font.ascender)
        )

        attributedWord.draw(at: drawPoint)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
