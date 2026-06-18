import AppKit
import Foundation

struct WallpaperTextRun {
    var attributedWord: NSAttributedString
    var drawPoint: CGPoint
    var textBounds: CGRect
}

enum WallpaperTextMeasurer {
    static let boundsTolerance: CGFloat = 4

    static func measuredSize(
        for word: String,
        fontSize: Double,
        opacity: Double
    ) -> CoreSize {
        let metrics = makeMetrics(
            word: word,
            fontSize: fontSize,
            opacity: opacity
        )

        return CoreSize(
            width: ceil(metrics.measuredBounds.width),
            height: ceil(metrics.measuredBounds.height)
        )
    }

    static func makePlacement(
        word: String,
        rect: CoreRect,
        fontSize: Double,
        depth: Double,
        opacity: Double
    ) -> LayoutWordPlacement {
        let metrics = makeMetrics(
            word: word,
            fontSize: fontSize,
            opacity: opacity
        )

        return LayoutWordPlacement(
            word: word,
            rect: rect,
            baseline: CorePoint(
                x: rect.origin.x - Double(metrics.measuredBounds.minX),
                y: rect.origin.y + metrics.baselineOffsetFromTextTop
            ),
            fontSize: fontSize,
            depth: depth,
            opacity: opacity
        )
    }

    static func textRun(for placement: LayoutWordPlacement) -> WallpaperTextRun {
        let metrics = makeMetrics(
            word: placement.word,
            fontSize: placement.fontSize,
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

        return WallpaperTextRun(
            attributedWord: metrics.attributedWord,
            drawPoint: drawPoint,
            textBounds: textBounds
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
        opacity: Double
    ) -> WallpaperTextMetrics {
        let fontSize = CGFloat(max(fontSize, 1))
        let opacity = CGFloat(clamp(opacity, to: 0...1))
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
            string: word,
            attributes: attributes
        )
        let measuredBounds = attributedWord.boundingRect(
            with: CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).standardized

        return WallpaperTextMetrics(
            attributedWord: attributedWord,
            font: font,
            measuredBounds: measuredBounds
        )
    }

    private static func clamp(
        _ value: Double,
        to range: ClosedRange<Double>
    ) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

private struct WallpaperTextMetrics {
    var attributedWord: NSAttributedString
    var font: NSFont
    var measuredBounds: CGRect

    var baselineOffsetFromTextTop: Double {
        Double(font.ascender - measuredBounds.minY)
    }
}
