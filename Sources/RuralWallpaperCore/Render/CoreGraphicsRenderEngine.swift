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
        let canvasWidth = display.pixelSize.width
        let canvasHeight = display.pixelSize.height

        guard canvasWidth > 0, canvasHeight > 0 else {
            throw RenderError.invalidDisplaySize
        }

        guard plan.displayID == display.id else {
            throw RenderError.invalidLayout
        }

        let backgroundImage = try decodeImage(from: background)
        let context = try makeBitmapContext(width: canvasWidth, height: canvasHeight)
        let canvas = CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)

        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(canvas)
        drawScaleToFill(image: backgroundImage, in: canvas, context: context)
        try drawWords(plan, in: canvas, context: context)

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
        _ plan: LayoutPlan,
        in canvas: CGRect,
        context: CGContext
    ) throws {
        guard !plan.wordPlacements.isEmpty else { return }

        let textRuns = try plan.wordPlacements.map {
            try makeTextRun(for: $0, depthMode: plan.depthMode, canvas: canvas)
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        defer {
            NSGraphicsContext.restoreGraphicsState()
        }

        for textRun in textRuns {
            textRun.attributedWord.draw(at: textRun.drawPoint)
        }
    }

    private func makeTextRun(
        for placement: LayoutWordPlacement,
        depthMode: LayoutDepthMode,
        canvas: CGRect
    ) throws -> WallpaperTextRun {
        let textRun = WallpaperTextMeasurer.textRun(
            for: placement,
            depthMode: depthMode
        )
        let placementRect = WallpaperTextMeasurer.cgRect(from: placement.rect)

        guard placementRect.contains(
            textRun.textBounds,
            tolerance: WallpaperTextMeasurer.boundsTolerance
        ),
              canvas.contains(
                textRun.textBounds,
                tolerance: WallpaperTextMeasurer.boundsTolerance
              ) else {
            throw RenderError.invalidLayout
        }

        return textRun
    }
}

private extension CGRect {
    func contains(_ rect: CGRect, tolerance: CGFloat) -> Bool {
        rect.minX >= minX - tolerance
            && rect.maxX <= maxX + tolerance
            && rect.minY >= minY - tolerance
            && rect.maxY <= maxY + tolerance
    }
}
