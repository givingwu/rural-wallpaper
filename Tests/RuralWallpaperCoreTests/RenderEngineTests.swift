import AppKit
import XCTest
@testable import RuralWallpaperCore

final class RenderEngineTests: XCTestCase {
    func testRenderedPNGDimensionsMatchDisplayPixelSize() throws {
        let display = makeDisplay(width: 320, height: 180)
        let plan = makePlan(display: display)
        let background = try makeSolidPNG(width: 160, height: 90, color: .black)
        let engine = CoreGraphicsRenderEngine()

        let rendered = try engine.render(
            background: background,
            plan: plan,
            display: display
        )
        let output = try decodePNG(rendered.pngData)

        XCTAssertEqual(rendered.displayID, display.id)
        XCTAssertEqual(rendered.pixelSize, display.pixelSize)
        XCTAssertEqual(rendered.layoutPlan, plan)
        XCTAssertEqual(output.pixelsWide, display.pixelSize.width)
        XCTAssertEqual(output.pixelsHigh, display.pixelSize.height)
    }

    func testGlassOverlayRenderOutputsDisplaySizedWallpaperWithVisibleText() throws {
        let display = makeDisplay(width: 640, height: 360)
        let background = try makeSolidPNG(
            width: 640,
            height: 360,
            color: NSColor(calibratedRed: 0.08, green: 0.14, blue: 0.18, alpha: 1)
        )
        let engine = CoreGraphicsRenderEngine()

        let rendered = try engine.renderGlassOverlay(
            background: background,
            words: Array(realisticVocabularyItems().prefix(3)),
            display: display
        )
        let output = try decodePNG(rendered.pngData)

        XCTAssertEqual(rendered.displayID, display.id)
        XCTAssertEqual(rendered.pixelSize, display.pixelSize)
        XCTAssertEqual(rendered.words.map(\.word), ["meadow", "harvest", "orchard"])
        XCTAssertEqual(output.pixelsWide, display.pixelSize.width)
        XCTAssertEqual(output.pixelsHigh, display.pixelSize.height)
        XCTAssertTrue(
            containsReadableLightPixel(output),
            "glass overlay should render readable but subtle light text"
        )
    }

    func testGlassOverlayUsesDistributedBadgesWithChineseDefinitions() throws {
        let canvas = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let engine = CoreGraphicsRenderEngine()
        let words = Array(realisticVocabularyItems().prefix(5))

        let badges = engine.makeGlassWordBadges(words: words, in: canvas)

        XCTAssertEqual(badges.map(\.displayText), words.map(\.word))
        XCTAssertEqual(
            badges.map(\.detailText),
            Array(repeating: "名词 · 测试词", count: 5)
        )
        XCTAssertEqual(badges.first?.role, .primary)
        XCTAssertEqual(badges.dropFirst().map(\.role), Array(repeating: .secondary, count: 4))
        XCTAssertTrue(badges.allSatisfy { !$0.displayText.containsCJKCharacters })
        XCTAssertTrue(badges.allSatisfy { ($0.detailText ?? "").containsCJKCharacters })
        XCTAssertTrue(badges.allSatisfy { $0.style.fillAlpha <= 0.12 })
        XCTAssertTrue(badges.allSatisfy { $0.style.strokeAlpha <= 0.28 })
        XCTAssertTrue(badges.allSatisfy { $0.style.textAlpha <= 0.82 })

        let horizontalBands = Set(badges.map { Int(($0.rect.midX / canvas.width) * 3) })
        let verticalBands = Set(badges.map { Int(($0.rect.midY / canvas.height) * 3) })
        XCTAssertGreaterThanOrEqual(horizontalBands.count, 2)
        XCTAssertGreaterThanOrEqual(verticalBands.count, 2)

        for index in badges.indices {
            for otherIndex in badges.indices where otherIndex > index {
                XCTAssertFalse(
                    badges[index].rect.insetBy(dx: -18, dy: -18)
                        .intersects(badges[otherIndex].rect),
                    "glass word badges should not visually cluster"
                )
            }
        }
    }

    func testGlassOverlayDrawsPrimaryBadgeTextUpright() throws {
        let display = makeDisplay(width: 900, height: 500)
        let background = try makeSolidPNG(width: 900, height: 500, color: .black)
        let engine = CoreGraphicsRenderEngine()
        let words = [
            makeVocabularyItem(word: "Fiiii", partOfSpeech: ""),
            makeVocabularyItem(word: "plain", partOfSpeech: ""),
            makeVocabularyItem(word: "ridge", partOfSpeech: "")
        ]

        let rendered = try engine.renderGlassOverlay(
            background: background,
            words: words,
            display: display
        )
        let output = try decodePNG(rendered.pngData)
        let primaryBadge = try XCTUnwrap(
            engine.makeGlassWordBadges(
                words: words,
                in: CGRect(x: 0, y: 0, width: 900, height: 500)
            ).first
        )
        let counts = try primaryGlyphStemCounts(in: output, badge: primaryBadge)

        XCTAssertGreaterThan(
            counts.left,
            counts.right,
            "An upright Fiiii has its wide glyph mass on the left; reversed or mirrored badge text moves it to the right."
        )
    }

    func testRenderedPNGContainsVisibleWordPixels() throws {
        let display = makeDisplay(width: 360, height: 220)
        let opacity = 0.98
        let textSize = WallpaperTextMeasurer.measuredSize(
            for: "FIELD",
            fontSize: 72,
            depth: 0,
            opacity: opacity
        )
        let plan = makePlan(
            display: display,
            placements: [
                WallpaperTextMeasurer.makePlacement(
                    word: "FIELD",
                    rect: CoreRect(
                        x: 42,
                        y: 58,
                        width: textSize.width,
                        height: textSize.height
                    ),
                    fontSize: 72,
                    depth: 0,
                    opacity: opacity,
                    depthMode: .flat
                )
            ]
        )
        let background = try makeSolidPNG(width: 360, height: 220, color: .black)
        let engine = CoreGraphicsRenderEngine()

        let rendered = try engine.render(
            background: background,
            plan: plan,
            display: display
        )
        let output = try decodePNG(rendered.pngData)

        XCTAssertTrue(
            containsBrightPixel(output),
            "rendered output should contain near-white text pixels"
        )
    }

    func testRenderedWordPixelsStayInsidePlacementRectWithTolerance() throws {
        let display = makeDisplay(width: 420, height: 240)
        let placement = LayoutWordPlacement(
            word: "MEADOW",
            rect: CoreRect(x: 18, y: 28, width: 300, height: 86),
            baseline: CorePoint(x: 18, y: 92),
            fontSize: 54,
            depth: 0,
            opacity: 0.98
        )
        let plan = makePlan(display: display, placements: [placement])
        let background = try makeSolidPNG(width: 420, height: 240, color: .black)
        let engine = CoreGraphicsRenderEngine()

        let rendered = try engine.render(
            background: background,
            plan: plan,
            display: display
        )
        let output = try decodePNG(rendered.pngData)
        let brightBounds = try XCTUnwrap(brightPixelBounds(in: output))

        assertPixelBounds(
            brightBounds,
            isInside: placement.rect,
            tolerance: Double(WallpaperTextMeasurer.boundsTolerance)
        )
    }

    func testTextStyleUsesPlacementDepthWithoutChangingBoundsContract() throws {
        let basePlacement = WallpaperTextMeasurer.makePlacement(
            word: "MEADOW",
            rect: CoreRect(x: 24, y: 36, width: 250, height: 78),
            fontSize: 52,
            depth: 0,
            opacity: 0.95
        )
        let foregroundPlacement = WallpaperTextMeasurer.makePlacement(
            word: "MEADOW",
            rect: basePlacement.rect,
            fontSize: basePlacement.fontSize,
            depth: 0.75,
            opacity: basePlacement.opacity
        )

        let baseRun = WallpaperTextMeasurer.textRun(for: basePlacement)
        let foregroundRun = WallpaperTextMeasurer.textRun(for: foregroundPlacement)
        let baseShadow = try XCTUnwrap(
            baseRun.attributedWord.attribute(
                .shadow,
                at: 0,
                effectiveRange: nil
            ) as? NSShadow
        )
        let foregroundShadow = try XCTUnwrap(
            foregroundRun.attributedWord.attribute(
                .shadow,
                at: 0,
                effectiveRange: nil
            ) as? NSShadow
        )

        XCTAssertNotEqual(baseShadow.shadowBlurRadius, foregroundShadow.shadowBlurRadius)
        XCTAssertNotEqual(baseShadow.shadowOffset, foregroundShadow.shadowOffset)
        XCTAssertNotEqual(shadowAlpha(baseShadow), shadowAlpha(foregroundShadow))
        assertCGRect(
            foregroundRun.renderBounds,
            isInside: WallpaperTextMeasurer.cgRect(from: foregroundPlacement.rect),
            tolerance: WallpaperTextMeasurer.boundsTolerance
        )
        XCTAssertGreaterThanOrEqual(
            foregroundRun.renderBounds.width,
            foregroundRun.textBounds.width
        )
        XCTAssertGreaterThanOrEqual(
            foregroundRun.renderBounds.height,
            foregroundRun.textBounds.height
        )
    }

    func testTooSmallTextRectThrowsInvalidLayout() throws {
        let display = makeDisplay(width: 420, height: 240)
        let plan = makePlan(
            display: display,
            placements: [
                LayoutWordPlacement(
                    word: "MEADOW",
                    rect: CoreRect(x: 18, y: 28, width: 80, height: 24),
                    baseline: CorePoint(x: 18, y: 92),
                    fontSize: 54,
                    depth: 0,
                    opacity: 0.98
                )
            ]
        )
        let background = try makeSolidPNG(width: 420, height: 240, color: .black)
        let engine = CoreGraphicsRenderEngine()

        XCTAssertThrowsError(
            try engine.render(
                background: background,
                plan: plan,
                display: display
            )
        ) { error in
            XCTAssertEqual(error as? RenderError, .invalidLayout)
        }
    }

    func testInvalidFontSizeThrowsInvalidLayout() throws {
        let display = makeDisplay(width: 420, height: 240)
        let plan = makePlan(
            display: display,
            placements: [
                LayoutWordPlacement(
                    word: "MEADOW",
                    rect: CoreRect(x: 18, y: 28, width: 300, height: 86),
                    baseline: CorePoint(x: 18, y: 92),
                    fontSize: 0,
                    depth: 0,
                    opacity: 0.98
                )
            ]
        )
        let background = try makeSolidPNG(width: 420, height: 240, color: .black)
        let engine = CoreGraphicsRenderEngine()

        XCTAssertThrowsError(
            try engine.render(
                background: background,
                plan: plan,
                display: display
            )
        ) { error in
            XCTAssertEqual(error as? RenderError, .invalidLayout)
        }
    }

    func testShadowRenderBoundsOutsidePlacementThrowsInvalidLayout() throws {
        let display = makeDisplay(width: 420, height: 240)
        let flatSize = WallpaperTextMeasurer.measuredSize(
            for: "MEADOW",
            fontSize: 52,
            depth: 0,
            opacity: 0.98
        )
        var placement = WallpaperTextMeasurer.makePlacement(
            word: "MEADOW",
            rect: CoreRect(
                x: 28,
                y: 40,
                width: flatSize.width,
                height: flatSize.height
            ),
            fontSize: 52,
            depth: 0,
            opacity: 0.98
        )
        placement.depth = 1
        let plan = makePlan(display: display, placements: [placement], depthMode: .depthAware)
        let background = try makeSolidPNG(width: 420, height: 240, color: .black)
        let engine = CoreGraphicsRenderEngine()

        XCTAssertThrowsError(
            try engine.render(
                background: background,
                plan: plan,
                display: display
            )
        ) { error in
            XCTAssertEqual(error as? RenderError, .invalidLayout)
        }
    }

    func testWordLayoutPlannerCandidatesRenderSuccessfullyForRealisticWords() throws {
        let display = makeDisplay(width: 1440, height: 900)
        let analysis = ImageAnalysis(
            summary: "A calm meadow with a barn, orchard, and distant ridge.",
            safeTextRegions: [
                CoreRect(x: 180, y: 230, width: 980, height: 280)
            ],
            lowDetailRects: [
                CoreRect(x: 180, y: 230, width: 980, height: 280)
            ],
            maskConfidence: 0.9
        )
        let planner = WordLayoutPlanner()
        let engine = CoreGraphicsRenderEngine()
        let background = try makeSolidPNG(width: 1440, height: 900, color: .black)

        for wordCount in 3...5 {
            let plan = try XCTUnwrap(
                planner.makeLayoutCandidates(
                    display: display,
                    analysis: analysis,
                    words: Array(realisticVocabularyItems().prefix(wordCount)),
                    maxCandidates: 1
                ).first
            )

            let rendered = try engine.render(
                background: background,
                plan: plan,
                display: display
            )
            let output = try decodePNG(rendered.pngData)

            XCTAssertEqual(output.pixelsWide, display.pixelSize.width)
            XCTAssertEqual(output.pixelsHigh, display.pixelSize.height)
            XCTAssertTrue(containsBrightPixel(output))
        }
    }

    func testPlanDisplayIDMismatchThrowsInvalidLayout() throws {
        let display = makeDisplay(width: 320, height: 180)
        let plan = LayoutPlan(
            displayID: "different-display",
            wordPlacements: [],
            depthMode: .flat,
            score: 0.9
        )
        let background = try makeSolidPNG(width: 320, height: 180, color: .black)
        let engine = CoreGraphicsRenderEngine()

        XCTAssertThrowsError(
            try engine.render(
                background: background,
                plan: plan,
                display: display
            )
        ) { error in
            XCTAssertEqual(error as? RenderError, .invalidLayout)
        }
    }

    func testLayoutPlanTextRectsAreInsideCanvasBounds() {
        let display = makeDisplay(width: 400, height: 260)
        let plan = makePlan(
            display: display,
            placements: [
                LayoutWordPlacement(
                    word: "meadow",
                    rect: CoreRect(x: 32, y: 40, width: 160, height: 64),
                    baseline: CorePoint(x: 32, y: 90),
                    fontSize: 48,
                    depth: 0,
                    opacity: 0.95
                ),
                LayoutWordPlacement(
                    word: "ridge",
                    rect: CoreRect(x: 220, y: 152, width: 126, height: 50),
                    baseline: CorePoint(x: 220, y: 190),
                    fontSize: 38,
                    depth: 0,
                    opacity: 0.88
                )
            ]
        )
        let canvas = CoreRect(
            x: 0,
            y: 0,
            width: Double(display.pixelSize.width),
            height: Double(display.pixelSize.height)
        )

        for placement in plan.wordPlacements {
            XCTAssertTrue(
                canvas.contains(placement.rect),
                "\(placement.word) rect should be inside the render canvas"
            )
        }
    }

    func testBackgroundSizeMismatchUsesScaleToFillCrop() throws {
        let display = makeDisplay(width: 200, height: 200)
        let plan = makePlan(display: display, placements: [])
        let background = try makeHorizontalStripPNG(
            width: 400,
            height: 200,
            leftWidth: 100,
            rightWidth: 100
        )
        let engine = CoreGraphicsRenderEngine()

        let rendered = try engine.render(
            background: background,
            plan: plan,
            display: display
        )
        let output = try decodePNG(rendered.pngData)

        assertMostlyGreen(output, x: 8, y: 8)
        assertMostlyGreen(output, x: 100, y: 100)
        assertMostlyGreen(output, x: 191, y: 191)
    }

    func testTallBackgroundSizeMismatchUsesScaleToFillCrop() throws {
        let display = makeDisplay(width: 200, height: 200)
        let plan = makePlan(display: display, placements: [])
        let background = try makeVerticalStripPNG(
            width: 200,
            height: 400,
            lowerHeight: 100,
            upperHeight: 100
        )
        let engine = CoreGraphicsRenderEngine()

        let rendered = try engine.render(
            background: background,
            plan: plan,
            display: display
        )
        let output = try decodePNG(rendered.pngData)

        assertMostlyGreen(output, x: 8, y: 8)
        assertMostlyGreen(output, x: 100, y: 100)
        assertMostlyGreen(output, x: 191, y: 191)
    }

    func testInvalidBackgroundImageThrowsClearRenderError() {
        let display = makeDisplay(width: 100, height: 100)
        let engine = CoreGraphicsRenderEngine()

        XCTAssertThrowsError(
            try engine.render(
                background: Data("not an image".utf8),
                plan: makePlan(display: display),
                display: display
            )
        ) { error in
            XCTAssertEqual(error as? RenderError, .invalidBackgroundImage)
        }
    }

    func testInvalidDisplaySizeThrowsBeforeDecodingBackground() {
        let display = makeDisplay(width: 0, height: 100)
        let engine = CoreGraphicsRenderEngine()

        XCTAssertThrowsError(
            try engine.render(
                background: Data("not an image".utf8),
                plan: makePlan(display: display),
                display: display
            )
        ) { error in
            XCTAssertEqual(error as? RenderError, .invalidDisplaySize)
        }
    }

    private func makeDisplay(width: Int, height: Int) -> DisplayTarget {
        DisplayTarget(
            id: "display-main",
            frame: CoreRect(x: 0, y: 0, width: Double(width), height: Double(height)),
            pixelSize: PixelSize(width: width, height: height),
            scale: 2,
            colorSpace: "Display P3",
            isMain: true,
            friendlyName: "Built-in Display"
        )
    }

    private func realisticVocabularyItems() -> [VocabularyItem] {
        [
            makeVocabularyItem(word: "meadow"),
            makeVocabularyItem(word: "harvest"),
            makeVocabularyItem(word: "orchard"),
            makeVocabularyItem(word: "ridge"),
            makeVocabularyItem(word: "pasture")
        ]
    }

    private func makeVocabularyItem(word: String, partOfSpeech: String = "noun") -> VocabularyItem {
        VocabularyItem(
            word: word,
            partOfSpeech: partOfSpeech,
            zhDefinition: "测试词",
            example: "The word fits a calm rural wallpaper.",
            difficulty: 2,
            sourceReason: "Render integration test fixture."
        )
    }

    private func makePlan(
        display: DisplayTarget,
        placements: [LayoutWordPlacement] = [
            LayoutWordPlacement(
                word: "meadow",
                rect: CoreRect(x: 36, y: 42, width: 230, height: 76),
                baseline: CorePoint(x: 36, y: 98),
                fontSize: 48,
                depth: 0,
                opacity: 0.95
            )
        ],
        depthMode: LayoutDepthMode = .flat
    ) -> LayoutPlan {
        LayoutPlan(
            displayID: display.id,
            wordPlacements: placements,
            depthMode: depthMode,
            score: 0.9
        )
    }

    private func makeSolidPNG(width: Int, height: Int, color: NSColor) throws -> Data {
        let image = try makeImage(width: width, height: height) { context in
            context.setFillColor(color.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }

        return try pngData(from: image)
    }

    private func makeVerticalStripPNG(
        width: Int,
        height: Int,
        lowerHeight: Int,
        upperHeight: Int
    ) throws -> Data {
        let centerHeight = height - lowerHeight - upperHeight
        let image = try makeImage(width: width, height: height) { context in
            context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: lowerHeight))
            context.setFillColor(CGColor(red: 0, green: 1, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: lowerHeight, width: width, height: centerHeight))
            context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: height - upperHeight, width: width, height: upperHeight))
        }

        return try pngData(from: image)
    }

    private func makeHorizontalStripPNG(
        width: Int,
        height: Int,
        leftWidth: Int,
        rightWidth: Int
    ) throws -> Data {
        let centerWidth = width - leftWidth - rightWidth
        let image = try makeImage(width: width, height: height) { context in
            context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: leftWidth, height: height))
            context.setFillColor(CGColor(red: 0, green: 1, blue: 0, alpha: 1))
            context.fill(CGRect(x: leftWidth, y: 0, width: centerWidth, height: height))
            context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
            context.fill(CGRect(x: width - rightWidth, y: 0, width: rightWidth, height: height))
        }

        return try pngData(from: image)
    }

    private func makeImage(
        width: Int,
        height: Int,
        draw: (CGContext) -> Void
    ) throws -> CGImage {
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let context = try XCTUnwrap(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        )

        draw(context)
        return try XCTUnwrap(context.makeImage())
    }

    private func pngData(from image: CGImage) throws -> Data {
        let bitmap = NSBitmapImageRep(cgImage: image)
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }

    private func decodePNG(_ data: Data) throws -> NSBitmapImageRep {
        try XCTUnwrap(NSBitmapImageRep(data: data))
    }

    private func containsBrightPixel(_ image: NSBitmapImageRep) -> Bool {
        for y in 0..<image.pixelsHigh {
            for x in 0..<image.pixelsWide {
                guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                    continue
                }

                if color.redComponent > 0.82
                    && color.greenComponent > 0.82
                    && color.blueComponent > 0.82
                    && color.alphaComponent > 0.7 {
                    return true
                }
            }
        }

        return false
    }

    private func containsReadableLightPixel(_ image: NSBitmapImageRep) -> Bool {
        for y in 0..<image.pixelsHigh {
            for x in 0..<image.pixelsWide {
                guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                    continue
                }

                if color.redComponent > 0.58
                    && color.greenComponent > 0.58
                    && color.blueComponent > 0.58
                    && color.alphaComponent > 0.6 {
                    return true
                }
            }
        }

        return false
    }

    private func primaryGlyphStemCounts(
        in image: NSBitmapImageRep,
        badge: GlassWordBadge
    ) throws -> (left: Int, right: Int) {
        let rect = badge.rect.integral
        let verticallyMirroredRect = CGRect(
            x: rect.minX,
            y: CGFloat(image.pixelsHigh) - rect.maxY,
            width: rect.width,
            height: rect.height
        )
        let bestRect = [rect, verticallyMirroredRect].max {
            readablePixelCount(in: image, cropRect: $0)
                < readablePixelCount(in: image, cropRect: $1)
        } ?? rect
        let glyphBounds = try XCTUnwrap(
            readablePixelBounds(in: image, cropRect: bestRect),
            "primary badge should contain readable glyph pixels"
        )
        let splitX = (glyphBounds.minX + glyphBounds.maxX) / 2
        var leftCount = 0
        var rightCount = 0

        for y in glyphBounds.minY...glyphBounds.maxY {
            for x in glyphBounds.minX...glyphBounds.maxX where isReadablePixel(image, x: x, y: y) {
                if x <= splitX {
                    leftCount += 1
                } else {
                    rightCount += 1
                }
            }
        }

        return (leftCount, rightCount)
    }

    private func readablePixelCount(in image: NSBitmapImageRep, cropRect: CGRect) -> Int {
        var count = 0
        for y in clampedYRange(cropRect, image: image) {
            for x in clampedXRange(cropRect, image: image) where isReadablePixel(image, x: x, y: y) {
                count += 1
            }
        }

        return count
    }

    private func readablePixelBounds(
        in image: NSBitmapImageRep,
        cropRect: CGRect
    ) -> PixelBounds? {
        var bounds: PixelBounds?

        for y in clampedYRange(cropRect, image: image) {
            for x in clampedXRange(cropRect, image: image) where isReadablePixel(image, x: x, y: y) {
                bounds = bounds?.expanded(toIncludeX: x, y: y)
                    ?? PixelBounds(minX: x, minY: y, maxX: x, maxY: y)
            }
        }

        return bounds
    }

    private func clampedXRange(_ rect: CGRect, image: NSBitmapImageRep) -> Range<Int> {
        max(0, Int(rect.minX))..<min(image.pixelsWide, Int(rect.maxX))
    }

    private func clampedYRange(_ rect: CGRect, image: NSBitmapImageRep) -> Range<Int> {
        max(0, Int(rect.minY))..<min(image.pixelsHigh, Int(rect.maxY))
    }

    private func isReadablePixel(_ image: NSBitmapImageRep, x: Int, y: Int) -> Bool {
        guard (0..<image.pixelsWide).contains(x),
              (0..<image.pixelsHigh).contains(y),
              let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
            return false
        }

        let luminance = (color.redComponent + color.greenComponent + color.blueComponent) / 3
        return luminance > 0.56 && color.alphaComponent > 0.6
    }

    private func brightPixelBounds(in image: NSBitmapImageRep) -> PixelBounds? {
        var bounds: PixelBounds?

        for y in 0..<image.pixelsHigh {
            for x in 0..<image.pixelsWide {
                guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                    continue
                }

                guard color.redComponent > 0.82,
                      color.greenComponent > 0.82,
                      color.blueComponent > 0.82,
                      color.alphaComponent > 0.7 else {
                    continue
                }

                let canvasY = image.pixelsHigh - 1 - y
                bounds = bounds?.expanded(toIncludeX: x, y: canvasY)
                    ?? PixelBounds(minX: x, minY: canvasY, maxX: x, maxY: canvasY)
            }
        }

        return bounds
    }

    private func assertPixelBounds(
        _ bounds: PixelBounds,
        isInside rect: CoreRect,
        tolerance: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertGreaterThanOrEqual(
            Double(bounds.minX),
            rect.minX - tolerance,
            file: file,
            line: line
        )
        XCTAssertGreaterThanOrEqual(
            Double(bounds.minY),
            rect.minY - tolerance,
            file: file,
            line: line
        )
        XCTAssertLessThanOrEqual(
            Double(bounds.maxX),
            rect.maxX + tolerance,
            file: file,
            line: line
        )
        XCTAssertLessThanOrEqual(
            Double(bounds.maxY),
            rect.maxY + tolerance,
            file: file,
            line: line
        )
    }

    private func assertMostlyGreen(
        _ image: NSBitmapImageRep,
        x: Int,
        y: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
            XCTFail("missing color at \(x),\(y)", file: file, line: line)
            return
        }

        XCTAssertLessThan(color.redComponent, 0.08, file: file, line: line)
        XCTAssertGreaterThan(color.greenComponent, 0.90, file: file, line: line)
        XCTAssertLessThan(color.blueComponent, 0.08, file: file, line: line)
    }

    private func shadowAlpha(_ shadow: NSShadow) -> CGFloat? {
        shadow.shadowColor?
            .usingColorSpace(.deviceRGB)?
            .alphaComponent
    }

    private func assertCGRect(
        _ rect: CGRect,
        isInside bounds: CGRect,
        tolerance: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertGreaterThanOrEqual(rect.minX, bounds.minX - tolerance, file: file, line: line)
        XCTAssertGreaterThanOrEqual(rect.minY, bounds.minY - tolerance, file: file, line: line)
        XCTAssertLessThanOrEqual(rect.maxX, bounds.maxX + tolerance, file: file, line: line)
        XCTAssertLessThanOrEqual(rect.maxY, bounds.maxY + tolerance, file: file, line: line)
    }
}

private struct PixelBounds {
    var minX: Int
    var minY: Int
    var maxX: Int
    var maxY: Int

    func expanded(toIncludeX x: Int, y: Int) -> PixelBounds {
        PixelBounds(
            minX: min(minX, x),
            minY: min(minY, y),
            maxX: max(maxX, x),
            maxY: max(maxY, y)
        )
    }
}

private extension CoreRect {
    var minX: Double { origin.x }
    var minY: Double { origin.y }
    var maxX: Double { origin.x + size.width }
    var maxY: Double { origin.y + size.height }

    func contains(_ rect: CoreRect) -> Bool {
        rect.minX >= minX
            && rect.maxX <= maxX
            && rect.minY >= minY
            && rect.maxY <= maxY
    }
}

private extension String {
    var containsCJKCharacters: Bool {
        unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
                || (0x3400...0x4DBF).contains(Int(scalar.value))
                || (0x3040...0x30FF).contains(Int(scalar.value))
                || (0xAC00...0xD7AF).contains(Int(scalar.value))
        }
    }
}
