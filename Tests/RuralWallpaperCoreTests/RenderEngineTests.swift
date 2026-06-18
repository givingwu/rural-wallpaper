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

    func testRenderedPNGContainsVisibleWordPixels() throws {
        let display = makeDisplay(width: 360, height: 220)
        let plan = makePlan(
            display: display,
            placements: [
                LayoutWordPlacement(
                    word: "FIELD",
                    rect: CoreRect(x: 42, y: 58, width: 240, height: 90),
                    baseline: CorePoint(x: 42, y: 128),
                    fontSize: 72,
                    depth: 0,
                    opacity: 0.98
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
            tolerance: 4
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
        ]
    ) -> LayoutPlan {
        LayoutPlan(
            displayID: display.id,
            wordPlacements: placements,
            depthMode: .flat,
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
