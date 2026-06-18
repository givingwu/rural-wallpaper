import AppKit
import Foundation

struct WallpaperTextRun {
    var attributedWord: NSAttributedString
    var drawPoint: CGPoint
    var textBounds: CGRect
    var renderBounds: CGRect
}

enum WallpaperTextMeasurer {
    static let boundsTolerance: CGFloat = 4

    static func measuredSize(
        for word: String,
        fontSize: Double,
        depth: Double = 0,
        opacity: Double
    ) -> CoreSize {
        let metrics = makeMetrics(
            word: word,
            fontSize: fontSize,
            depth: depth,
            opacity: opacity
        )

        return CoreSize(
            width: ceil(metrics.renderBounds.width),
            height: ceil(metrics.renderBounds.height)
        )
    }

    static func makePlacement(
        word: String,
        rect: CoreRect,
        fontSize: Double,
        depth: Double,
        opacity: Double,
        depthMode: LayoutDepthMode = .depthAware
    ) -> LayoutWordPlacement {
        let metrics = makeMetrics(
            word: word,
            fontSize: fontSize,
            depth: effectiveDepth(depth, depthMode: depthMode),
            opacity: opacity
        )

        return LayoutWordPlacement(
            word: word,
            rect: rect,
            baseline: CorePoint(
                x: rect.origin.x - Double(metrics.renderBounds.minX),
                y: rect.origin.y + metrics.baselineOffsetFromRenderTop
            ),
            fontSize: fontSize,
            depth: depth,
            opacity: opacity
        )
    }

    static func textRun(for placement: LayoutWordPlacement) -> WallpaperTextRun {
        textRun(for: placement, depthMode: .depthAware)
    }

    static func textRun(
        for placement: LayoutWordPlacement,
        depthMode: LayoutDepthMode
    ) -> WallpaperTextRun {
        let metrics = makeMetrics(
            word: placement.word,
            fontSize: placement.fontSize,
            depth: effectiveDepth(for: placement, depthMode: depthMode),
            opacity: placement.opacity
        )
        let drawPoint = CGPoint(
            x: placement.baseline.x,
            y: placement.baseline.y - Double(metrics.font.ascender)
        )
        let textBounds = metrics.measuredBounds.offsetBy(
            dx: drawPoint.x,
            dy: drawPoint.y
        ).standardized
        let renderBounds = metrics.renderBounds.offsetBy(
            dx: drawPoint.x,
            dy: drawPoint.y
        ).standardized

        return WallpaperTextRun(
            attributedWord: metrics.attributedWord,
            drawPoint: drawPoint,
            textBounds: textBounds,
            renderBounds: renderBounds
        )
    }

    static func cgRect(from rect: CoreRect) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: rect.origin.y,
            width: rect.size.width,
            height: rect.size.height
        )
    }

    private static func makeMetrics(
        word: String,
        fontSize: Double,
        depth: Double,
        opacity: Double
    ) -> WallpaperTextMetrics {
        let fontSize = CGFloat(max(fontSize, 1))
        let depth = CGFloat(clamp(depth, to: 0...1))
        let opacity = CGFloat(clamp(opacity, to: 0...1))
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent((0.32 + depth * 0.18) * opacity)
        shadow.shadowBlurRadius = max(2, fontSize * (0.07 + depth * 0.04))
        shadow.shadowOffset = CGSize(width: 0, height: 2 + depth * 3)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(white: 0.98, alpha: opacity),
            .shadow: shadow
        ]
        let attributedWord = NSAttributedString(
            string: word,
            attributes: attributes
        )
        let measurementWord = NSAttributedString(
            string: word,
            attributes: [
                .font: font,
                .foregroundColor: NSColor(white: 0.98, alpha: opacity)
            ]
        )
        let measuredBounds = measurementWord.boundingRect(
            with: CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).standardized
        let renderBounds = renderedBounds(
            glyphBounds: measuredBounds,
            shadow: shadow,
            opacity: opacity
        )

        return WallpaperTextMetrics(
            attributedWord: attributedWord,
            font: font,
            measuredBounds: measuredBounds,
            renderBounds: renderBounds
        )
    }

    private static func renderedBounds(
        glyphBounds: CGRect,
        shadow: NSShadow,
        opacity: CGFloat
    ) -> CGRect {
        guard opacity > 0,
              let shadowColor = shadow.shadowColor as? NSColor,
              shadowColor.alphaComponent > 0 else {
            return glyphBounds
        }

        let blurRadius = max(0, shadow.shadowBlurRadius)
        let shadowBounds = glyphBounds
            .offsetBy(
                dx: shadow.shadowOffset.width,
                dy: shadow.shadowOffset.height
            )
            .insetBy(dx: -blurRadius, dy: -blurRadius)
            .standardized

        return glyphBounds.union(shadowBounds).standardized
    }

    private static func clamp(
        _ value: Double,
        to range: ClosedRange<Double>
    ) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private static func effectiveDepth(
        for placement: LayoutWordPlacement,
        depthMode: LayoutDepthMode
    ) -> Double {
        effectiveDepth(placement.depth, depthMode: depthMode)
    }

    private static func effectiveDepth(
        _ depth: Double,
        depthMode: LayoutDepthMode
    ) -> Double {
        switch depthMode {
        case .flat:
            return 0
        case .depthAware, .foregroundAware, .foregroundOnly:
            return depth
        }
    }
}

private struct WallpaperTextMetrics {
    var attributedWord: NSAttributedString
    var font: NSFont
    var measuredBounds: CGRect
    var renderBounds: CGRect

    var baselineOffsetFromRenderTop: Double {
        Double(font.ascender - renderBounds.minY)
    }
}
