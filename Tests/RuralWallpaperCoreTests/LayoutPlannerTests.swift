import XCTest
@testable import RuralWallpaperCore

final class LayoutPlannerTests: XCTestCase {
    func testThreeToFiveWordsAllGenerateInBoundsNonOverlappingPlacements() {
        let display = makeDisplay(width: 1440, height: 900)
        let analysis = ImageAnalysis(
            summary: "Open sky over a quiet field.",
            safeTextRegions: [
                CoreRect(x: 180, y: 230, width: 980, height: 260)
            ],
            maskConfidence: 0.9
        )
        let planner = WordLayoutPlanner()

        for wordCount in 3...5 {
            let plans = planner.makeLayoutCandidates(
                display: display,
                analysis: analysis,
                words: VocabularyItem.samples(count: wordCount),
                maxCandidates: 5
            )

            XCTAssertFalse(plans.isEmpty)
            for plan in plans {
                XCTAssertEqual(plan.wordPlacements.count, wordCount)
                XCTAssertLessThanOrEqual(plan.wordPlacements.count, 5)
                assertPlacementsAreInsideDisplay(plan.wordPlacements, display: display)
                assertWordRectsDoNotOverlap(plan.wordPlacements)
            }
        }
    }

    func testMainWordUsesLargerFontThanHelperWords() throws {
        let planner = WordLayoutPlanner()
        let plan = try XCTUnwrap(
            planner.makeLayoutCandidates(
                display: makeDisplay(),
                analysis: ImageAnalysis(
                    summary: "Quiet rural scene.",
                    lowDetailRects: [CoreRect(x: 180, y: 220, width: 900, height: 280)],
                    maskConfidence: 0.9
                ),
                words: VocabularyItem.samples(count: 5),
                maxCandidates: 1
            ).first
        )

        let mainFontSize = try XCTUnwrap(plan.wordPlacements.first?.fontSize)
        let helperFontSizes = plan.wordPlacements.dropFirst().map(\.fontSize)

        XCTAssertFalse(helperFontSizes.isEmpty)
        for helperFontSize in helperFontSizes {
            XCTAssertGreaterThan(mainFontSize, helperFontSize)
        }
    }

    func testPlannerCapsLayoutCandidatesAtFive() {
        let planner = WordLayoutPlanner()
        let plans = planner.makeLayoutCandidates(
            display: makeDisplay(width: 1800, height: 1000),
            analysis: ImageAnalysis(
                summary: "Several calm text regions.",
                safeTextRegions: [
                    CoreRect(x: 120, y: 300, width: 480, height: 260),
                    CoreRect(x: 660, y: 300, width: 480, height: 260),
                    CoreRect(x: 1200, y: 300, width: 480, height: 260)
                ],
                maskConfidence: 0.9
            ),
            words: VocabularyItem.samples(count: 3),
            maxCandidates: 10
        )

        XCTAssertLessThanOrEqual(plans.count, 5)
    }

    func testLongWordNarrowRegionPreservesEstimatedTextBounds() {
        let display = makeDisplay(width: 900, height: 600)
        let planner = WordLayoutPlanner()
        let plans = planner.makeLayoutCandidates(
            display: display,
            analysis: ImageAnalysis(
                summary: "A narrow quiet sky band.",
                safeTextRegions: [
                    CoreRect(x: 250, y: 180, width: 320, height: 260)
                ],
                maskConfidence: 0.9
            ),
            words: [
                makeVocabularyItem(word: "countryside"),
                makeVocabularyItem(word: "ridge"),
                makeVocabularyItem(word: "dusk")
            ],
            maxCandidates: 3
        )

        XCTAssertFalse(plans.isEmpty)

        for plan in plans {
            assertPlacementsAreInsideDisplay(plan.wordPlacements, display: display)
            assertWordRectsDoNotOverlap(plan.wordPlacements)

            for placement in plan.wordPlacements {
                let estimatedSize = estimatedTextSize(
                    for: placement.word,
                    fontSize: placement.fontSize
                )

                XCTAssertGreaterThanOrEqual(
                    placement.rect.size.width,
                    estimatedSize.width,
                    "\(placement.word) rect width is smaller than estimated text width"
                )
                XCTAssertGreaterThanOrEqual(
                    placement.rect.size.height,
                    estimatedSize.height,
                    "\(placement.word) rect height is smaller than estimated text height"
                )
            }
        }
    }

    func testPlacementsAvoidSubjectRects() throws {
        let display = makeDisplay(width: 1440, height: 900)
        let analysis = ImageAnalysis(
            summary: "A cottage blocks the lower center.",
            safeTextRegions: [
                CoreRect(x: 160, y: 220, width: 1080, height: 300)
            ],
            subjectRects: [
                CoreRect(x: 160, y: 210, width: 520, height: 320)
            ],
            lowDetailRects: [
                CoreRect(x: 180, y: 230, width: 420, height: 240),
                CoreRect(x: 780, y: 230, width: 420, height: 240)
            ],
            maskConfidence: 0.95
        )
        let planner = WordLayoutPlanner()

        let plan = try XCTUnwrap(
            planner.makeLayoutCandidates(
                display: display,
                analysis: analysis,
                words: VocabularyItem.samples(count: 4),
                maxCandidates: 3
            ).first
        )

        for placement in plan.wordPlacements {
            for subjectRect in analysis.subjectRects {
                XCTAssertFalse(
                    placement.rect.intersects(subjectRect),
                    "\(placement.word) intersects subject rect"
                )
            }
        }
    }

    func testNoReliableMaskUsesForegroundOnlyDepthMode() throws {
        let planner = WordLayoutPlanner()

        let plan = try XCTUnwrap(
            planner.makeLayoutCandidates(
                display: makeDisplay(),
                analysis: ImageAnalysis(
                    summary: "No dependable segmentation mask.",
                    safeTextRegions: [CoreRect(x: 120, y: 220, width: 920, height: 260)],
                    maskConfidence: 0.2
                ),
                words: VocabularyItem.samples(count: 3),
                maxCandidates: 1
            ).first
        )

        XCTAssertEqual(plan.depthMode, .foregroundOnly)
    }

    func testEmptySafeTextRegionsUsesUpperMiddleFallback() throws {
        let display = makeDisplay(width: 1200, height: 800)
        let planner = WordLayoutPlanner()

        let plan = try XCTUnwrap(
            planner.makeLayoutCandidates(
                display: display,
                analysis: ImageAnalysis(
                    summary: "Analyzer did not find reliable text regions.",
                    maskConfidence: 0.9
                ),
                words: VocabularyItem.samples(count: 4),
                maxCandidates: 1
            ).first
        )

        XCTAssertEqual(plan.wordPlacements.count, 4)
        assertPlacementsAreInsideDisplay(plan.wordPlacements, display: display)

        let fallbackBand = CoreRect(
            x: 0,
            y: Double(display.pixelSize.height) * 0.30,
            width: Double(display.pixelSize.width),
            height: Double(display.pixelSize.height) * 0.25
        )
        let placementCenters = plan.wordPlacements.map { $0.rect.center }

        XCTAssertTrue(
            placementCenters.allSatisfy { fallbackBand.contains($0) },
            "fallback placements should stay in the upper-middle band"
        )
    }

    private func makeDisplay(width: Int = 1280, height: Int = 800) -> DisplayTarget {
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

    private func makeVocabularyItem(word: String) -> VocabularyItem {
        VocabularyItem(
            word: word,
            partOfSpeech: "noun",
            zhDefinition: "测试词",
            example: "The word appears in a calm rural scene.",
            difficulty: 2,
            sourceReason: "Layout test fixture."
        )
    }

    private func estimatedTextSize(for word: String, fontSize: Double) -> CoreSize {
        let width = max(fontSize * 1.5, Double(word.count) * fontSize * 0.58)
        return CoreSize(width: width, height: fontSize * 1.18)
    }

    private func assertPlacementsAreInsideDisplay(
        _ placements: [LayoutWordPlacement],
        display: DisplayTarget,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let displayRect = CoreRect(
            x: 0,
            y: 0,
            width: Double(display.pixelSize.width),
            height: Double(display.pixelSize.height)
        )

        for placement in placements {
            XCTAssertTrue(
                displayRect.contains(placement.rect),
                "\(placement.word) is outside display bounds",
                file: file,
                line: line
            )
        }
    }

    private func assertWordRectsDoNotOverlap(
        _ placements: [LayoutWordPlacement],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for leftIndex in placements.indices {
            for rightIndex in placements.indices where rightIndex > leftIndex {
                XCTAssertFalse(
                    placements[leftIndex].rect.intersects(placements[rightIndex].rect),
                    "\(placements[leftIndex].word) overlaps \(placements[rightIndex].word)",
                    file: file,
                    line: line
                )
            }
        }
    }
}

private extension CoreRect {
    var minX: Double { origin.x }
    var minY: Double { origin.y }
    var maxX: Double { origin.x + size.width }
    var maxY: Double { origin.y + size.height }
    var center: CorePoint {
        CorePoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
    }

    func contains(_ point: CorePoint) -> Bool {
        point.x >= minX
            && point.x <= maxX
            && point.y >= minY
            && point.y <= maxY
    }

    func contains(_ rect: CoreRect) -> Bool {
        rect.minX >= minX
            && rect.maxX <= maxX
            && rect.minY >= minY
            && rect.maxY <= maxY
    }

    func intersects(_ other: CoreRect) -> Bool {
        minX < other.maxX
            && maxX > other.minX
            && minY < other.maxY
            && maxY > other.minY
    }
}
