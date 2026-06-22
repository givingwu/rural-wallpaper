import AppKit
import Foundation
import ImageIO
import CoreText

enum GlassWordBadgeRole: Equatable, Sendable {
    case primary
    case secondary
}

struct GlassWordBadgeStyle: Equatable, Sendable {
    var fontSize: CGFloat
    var fillAlpha: CGFloat
    var strokeAlpha: CGFloat
    var textAlpha: CGFloat
    var shadowAlpha: CGFloat
    var cornerRadius: CGFloat
}

struct GlassWordBadge: Equatable, Sendable {
    var displayText: String
    var detailText: String?
    var role: GlassWordBadgeRole
    var rect: CGRect
    var style: GlassWordBadgeStyle
}

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

    public func renderGlassOverlay(
        background: Data,
        words: [VocabularyItem],
        display: DisplayTarget
    ) throws -> RenderedGlassWallpaper {
        let canvasWidth = display.pixelSize.width
        let canvasHeight = display.pixelSize.height

        guard canvasWidth > 0, canvasHeight > 0 else {
            throw RenderError.invalidDisplaySize
        }
        guard (3...5).contains(words.count) else {
            throw RenderError.invalidLayout
        }

        let backgroundImage = try decodeImage(from: background)
        let context = try makeBitmapContext(width: canvasWidth, height: canvasHeight)
        let canvas = CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)

        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(canvas)
        drawScaleToFill(image: backgroundImage, in: canvas, context: context)
        drawGlassWordBadges(makeGlassWordBadges(words: words, in: canvas), context: context)

        guard let renderedImage = context.makeImage() else {
            throw RenderError.pngEncodingFailed
        }

        let bitmap = NSBitmapImageRep(cgImage: renderedImage)
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw RenderError.pngEncodingFailed
        }

        return RenderedGlassWallpaper(
            pngData: pngData,
            displayID: display.id,
            words: words,
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

    func makeGlassWordBadges(words: [VocabularyItem], in canvas: CGRect) -> [GlassWordBadge] {
        let slots = [
            CGPoint(x: 0.08, y: 0.10),
            CGPoint(x: 0.62, y: 0.18),
            CGPoint(x: 0.12, y: 0.70),
            CGPoint(x: 0.66, y: 0.68),
            CGPoint(x: 0.40, y: 0.43)
        ]
        let safeInset = max(24, min(canvas.width, canvas.height) * 0.035)
        let primaryFontSize = min(max(canvas.width * 0.052, 40), 96)
        let secondaryFontSize = min(max(canvas.width * 0.030, 24), 48)

        return words.enumerated().map { index, item in
            let role: GlassWordBadgeRole = index == 0 ? .primary : .secondary
            let fontSize = role == .primary ? primaryFontSize : secondaryFontSize
            let displayText = englishOnlyText(item.word)
            let detailText = role == .primary ? englishOnlyDetail(item.partOfSpeech) : nil
            let style = GlassWordBadgeStyle(
                fontSize: fontSize,
                fillAlpha: role == .primary ? 0.105 : 0.075,
                strokeAlpha: role == .primary ? 0.26 : 0.20,
                textAlpha: role == .primary ? 0.80 : 0.66,
                shadowAlpha: role == .primary ? 0.30 : 0.22,
                cornerRadius: role == .primary ? 26 : 20
            )
            return GlassWordBadge(
                displayText: displayText,
                detailText: detailText,
                role: role,
                rect: glassBadgeRect(
                    text: displayText,
                    detailText: detailText,
                    role: role,
                    style: style,
                    slot: slots[index % slots.count],
                    canvas: canvas,
                    safeInset: safeInset
                ),
                style: style
            )
        }
    }

    private func glassBadgeRect(
        text: String,
        detailText: String?,
        role: GlassWordBadgeRole,
        style: GlassWordBadgeStyle,
        slot: CGPoint,
        canvas: CGRect,
        safeInset: CGFloat
    ) -> CGRect {
        let weight: NSFont.Weight = role == .primary ? .bold : .semibold
        let textWidth = ceil(
            (text as NSString).size(
                withAttributes: [.font: NSFont.systemFont(ofSize: style.fontSize, weight: weight)]
            ).width
        )
        let horizontalPadding = role == .primary ? style.fontSize * 0.42 : style.fontSize * 0.52
        let minWidth = role == .primary ? canvas.width * 0.15 : canvas.width * 0.085
        let maxWidth = role == .primary ? canvas.width * 0.36 : canvas.width * 0.24
        let width = min(max(textWidth + horizontalPadding * 2, minWidth), maxWidth)
        let detailHeight = detailText == nil ? 0 : style.fontSize * 0.34
        let verticalPadding = role == .primary ? style.fontSize * 0.25 : style.fontSize * 0.22
        let height = ceil(style.fontSize * 1.04 + detailHeight + verticalPadding * 2)
        let rawX = canvas.minX + canvas.width * slot.x
        let rawY = canvas.minY + canvas.height * slot.y
        let x = min(max(rawX, canvas.minX + safeInset), canvas.maxX - safeInset - width)
        let y = min(max(rawY, canvas.minY + safeInset), canvas.maxY - safeInset - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func englishOnlyText(_ text: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-' ")
        let value = String(text.unicodeScalars.filter { allowed.contains($0) })
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "word" : value
    }

    private func englishOnlyDetail(_ text: String) -> String? {
        let value = englishOnlyText(text).lowercased()
        return value == "word" ? nil : value
    }

    private func drawGlassWordBadges(
        _ badges: [GlassWordBadge],
        context: CGContext
    ) {
        context.saveGState()
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)

        for badge in badges {
            drawGlassBadgeBackground(badge)
        }
        NSGraphicsContext.restoreGraphicsState()
        context.restoreGState()

        for badge in badges {
            drawGlassBadgeText(badge, context: context)
        }
    }

    private func drawGlassBadgeBackground(_ badge: GlassWordBadge) {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(badge.style.shadowAlpha)
        shadow.shadowBlurRadius = badge.role == .primary ? 22 : 16
        shadow.shadowOffset = CGSize(width: 0, height: badge.role == .primary ? 10 : 7)
        shadow.set()

        let radius = min(badge.style.cornerRadius, badge.rect.height / 2)
        let path = NSBezierPath(roundedRect: badge.rect, xRadius: radius, yRadius: radius)
        NSColor.white.withAlphaComponent(badge.style.fillAlpha).setFill()
        path.fill()

        shadow.shadowColor = .clear
        shadow.set()

        NSColor.white.withAlphaComponent(badge.style.strokeAlpha).setStroke()
        path.lineWidth = badge.role == .primary ? 1.0 : 0.8
        path.stroke()

        let highlight = NSBezierPath(
            roundedRect: badge.rect.insetBy(dx: 6, dy: 6),
            xRadius: max(8, radius - 6),
            yRadius: max(8, radius - 6)
        )
        NSColor.white.withAlphaComponent(0.08).setStroke()
        highlight.lineWidth = 0.65
        highlight.stroke()
    }

    private func drawGlassBadgeText(_ badge: GlassWordBadge, context: CGContext) {
        let horizontalPadding = badge.role == .primary
            ? badge.style.fontSize * 0.42
            : badge.style.fontSize * 0.52
        let textY = badge.rect.minY + (badge.detailText == nil
            ? (badge.rect.height - badge.style.fontSize * 1.08) / 2
            : badge.style.fontSize * 0.20)
        let textRect = CGRect(
            x: badge.rect.minX + horizontalPadding,
            y: textY,
            width: badge.rect.width - horizontalPadding * 2,
            height: badge.style.fontSize * 1.15
        )
        drawCoreTextLine(
            badge.displayText,
            in: textRect,
            font: .systemFont(
                ofSize: badge.style.fontSize,
                weight: badge.role == .primary ? .bold : .semibold
            ),
            color: NSColor.white.withAlphaComponent(badge.style.textAlpha),
            shadowAlpha: badge.style.shadowAlpha,
            shadowBlur: badge.role == .primary ? 13 : 9,
            shadowOffset: CGSize(width: 0, height: badge.role == .primary ? 2 : 1),
            context: context
        )

        guard let detailText = badge.detailText else { return }

        drawCoreTextLine(
            detailText,
            in: CGRect(
                x: badge.rect.minX + horizontalPadding,
                y: textRect.maxY - badge.style.fontSize * 0.02,
                width: badge.rect.width - horizontalPadding * 2,
                height: badge.style.fontSize * 0.42
            ),
            font: .systemFont(ofSize: max(11, badge.style.fontSize * 0.28), weight: .medium),
            color: NSColor.white.withAlphaComponent(badge.style.textAlpha * 0.58),
            shadowAlpha: badge.style.shadowAlpha,
            shadowBlur: 7,
            shadowOffset: CGSize(width: 0, height: 1),
            context: context
        )
    }

    private func drawCoreTextLine(
        _ text: String,
        in rect: CGRect,
        font: NSFont,
        color: NSColor,
        shadowAlpha: CGFloat,
        shadowBlur: CGFloat,
        shadowOffset: CGSize,
        context: CGContext
    ) {
        guard !text.isEmpty, rect.width > 0, rect.height > 0 else { return }

        context.saveGState()
        defer { context.restoreGState() }

        context.clip(to: rect)
        context.textMatrix = .identity
        context.setShadow(
            offset: shadowOffset,
            blur: shadowBlur,
            color: NSColor.black.withAlphaComponent(shadowAlpha).cgColor
        )

        let textColor = color.usingColorSpace(.deviceRGB)?.cgColor ?? color.cgColor
        let ctFont = CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil)
        // 离屏 bitmap 文本路径会反向显示文本 run，因此先反转输入再交给 CoreText。
        let visualText = String(text.reversed())
        let attributedText = CFAttributedStringCreate(
            nil,
            visualText as CFString,
            [
                kCTFontAttributeName: ctFont,
                kCTForegroundColorAttributeName: textColor
            ] as CFDictionary
        )
        guard let attributedText else { return }

        let line = CTLineCreateWithAttributedString(attributedText)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let lineWidth = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))

        let baselineY = rect.minY + max(0, (rect.height - ascent - descent) / 2) + descent
        context.translateBy(x: rect.maxX, y: 0)
        context.scaleBy(x: -1, y: 1)
        context.textPosition = CGPoint(x: max(0, rect.width - lineWidth), y: baselineY)
        CTLineDraw(line, context)
    }

    private func makeTextRun(
        for placement: LayoutWordPlacement,
        depthMode: LayoutDepthMode,
        canvas: CGRect
    ) throws -> WallpaperTextRun {
        guard isValidPlacementInput(placement) else {
            throw RenderError.invalidLayout
        }

        let textRun = WallpaperTextMeasurer.textRun(
            for: placement,
            depthMode: depthMode
        )
        let placementRect = WallpaperTextMeasurer.cgRect(from: placement.rect)

        guard placementRect.contains(
            textRun.renderBounds,
            tolerance: WallpaperTextMeasurer.boundsTolerance
        ),
              canvas.contains(
                textRun.renderBounds,
                tolerance: WallpaperTextMeasurer.boundsTolerance
              ) else {
            throw RenderError.invalidLayout
        }

        return textRun
    }

    private func isValidPlacementInput(_ placement: LayoutWordPlacement) -> Bool {
        let rect = placement.rect
        let values = [
            rect.origin.x,
            rect.origin.y,
            rect.size.width,
            rect.size.height,
            placement.baseline.x,
            placement.baseline.y,
            placement.fontSize,
            placement.depth,
            placement.opacity
        ]

        return values.allSatisfy(\.isFinite)
            && rect.size.width > 0
            && rect.size.height > 0
            && placement.fontSize > 0
            && (0...1).contains(placement.depth)
            && (0...1).contains(placement.opacity)
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
