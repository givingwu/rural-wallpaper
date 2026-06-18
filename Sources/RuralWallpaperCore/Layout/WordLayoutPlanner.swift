public struct WordLayoutPlanner: LayoutPlanner {
    private let reliableMaskThreshold: Double

    public init(reliableMaskThreshold: Double = 0.5) {
        self.reliableMaskThreshold = reliableMaskThreshold
    }

    public func makeLayoutCandidates(
        display: DisplayTarget,
        analysis: ImageAnalysis,
        words: [VocabularyItem],
        maxCandidates: Int
    ) -> [LayoutPlan] {
        let candidateLimit = min(maxCandidates, 5)
        guard candidateLimit > 0 else { return [] }

        let selectedWords = Array(words.prefix(5))
        guard !selectedWords.isEmpty else { return [] }

        let displayRect = CoreRect(
            x: 0,
            y: 0,
            width: Double(display.pixelSize.width),
            height: Double(display.pixelSize.height)
        )
        let depthMode = makeDepthMode(for: analysis)
        let preferredRegions = makePreferredRegions(
            displayRect: displayRect,
            analysis: analysis
        )

        var candidates = makeCandidates(
            display: display,
            displayRect: displayRect,
            analysis: analysis,
            words: selectedWords,
            depthMode: depthMode,
            regionChoices: preferredRegions.primary
        )

        if candidates.isEmpty {
            candidates = makeCandidates(
                display: display,
                displayRect: displayRect,
                analysis: analysis,
                words: selectedWords,
                depthMode: depthMode,
                regionChoices: preferredRegions.fallback
            )
        }

        return Array(
            candidates
                .sorted { left, right in
                    if left.score == right.score {
                        let leftX = left.wordPlacements.first?.rect.origin.x ?? 0
                        let rightX = right.wordPlacements.first?.rect.origin.x ?? 0
                        return leftX < rightX
                    }
                    return left.score > right.score
                }
                .prefix(candidateLimit)
        )
    }

    private func makePreferredRegions(
        displayRect: CoreRect,
        analysis: ImageAnalysis
    ) -> (primary: [RegionChoice], fallback: [RegionChoice]) {
        let fallback = RegionChoice(
            rect: upperMiddleFallbackRegion(in: displayRect),
            preference: .fallback
        )

        if !analysis.lowDetailRects.isEmpty {
            return (
                primary: analysis.lowDetailRects.map {
                    RegionChoice(rect: $0.clamped(to: displayRect), preference: .lowDetail)
                },
                fallback: analysis.safeTextRegions.map {
                    RegionChoice(rect: $0.clamped(to: displayRect), preference: .safeText)
                } + [fallback]
            )
        }

        if !analysis.safeTextRegions.isEmpty {
            return (
                primary: analysis.safeTextRegions.map {
                    RegionChoice(rect: $0.clamped(to: displayRect), preference: .safeText)
                },
                fallback: [fallback]
            )
        }

        return (primary: [fallback], fallback: [])
    }

    private func upperMiddleFallbackRegion(in displayRect: CoreRect) -> CoreRect {
        CoreRect(
            x: displayRect.minX + displayRect.width * 0.16,
            y: displayRect.minY + displayRect.height * 0.30,
            width: displayRect.width * 0.68,
            height: displayRect.height * 0.25
        )
    }

    private func makeCandidates(
        display: DisplayTarget,
        displayRect: CoreRect,
        analysis: ImageAnalysis,
        words: [VocabularyItem],
        depthMode: LayoutDepthMode,
        regionChoices: [RegionChoice]
    ) -> [LayoutPlan] {
        var candidates: [LayoutPlan] = []

        for regionChoice in regionChoices {
            guard regionChoice.rect.width > 0, regionChoice.rect.height > 0 else {
                continue
            }

            for anchor in LayoutAnchor.allCases {
                for scale in [1.0, 0.9, 0.8, 0.7, 0.6] {
                    let placements = makePlacements(
                        in: regionChoice.rect,
                        words: words,
                        anchor: anchor,
                        scale: scale
                    )

                    guard isValid(
                        placements: placements,
                        displayRect: displayRect,
                        subjectRects: analysis.subjectRects
                    ) else {
                        continue
                    }

                    candidates.append(
                        LayoutPlan(
                            displayID: display.id,
                            wordPlacements: placements,
                            depthMode: depthMode,
                            score: score(
                                placements: placements,
                                displayRect: displayRect,
                                region: regionChoice,
                                analysis: analysis
                            )
                        )
                    )
                    break
                }
            }
        }

        return candidates
    }

    private func makePlacements(
        in region: CoreRect,
        words: [VocabularyItem],
        anchor: LayoutAnchor,
        scale: Double
    ) -> [LayoutWordPlacement] {
        let mainFontSize = fontSize(
            base: min(region.height * 0.28, 78),
            minimum: 38,
            scale: scale
        )
        let helperFontSize = fontSize(
            base: min(region.height * 0.15, mainFontSize * 0.54),
            minimum: 22,
            scale: scale
        )
        let mainTextSize = estimatedTextSize(for: words[0].word, fontSize: mainFontSize)
        let mainX = anchoredX(
            rectWidth: mainTextSize.width,
            in: region,
            anchor: anchor
        )
        let mainY = region.minY + region.height * 0.10
        let mainRect = CoreRect(
            x: mainX,
            y: mainY,
            width: mainTextSize.width,
            height: mainTextSize.height
        ).clamped(to: region)
        var placements = [
            makePlacement(
                word: words[0].word,
                rect: mainRect,
                fontSize: mainFontSize,
                depth: 0.0,
                opacity: 0.96
            )
        ]

        let helperWords = Array(words.dropFirst())
        guard !helperWords.isEmpty else { return placements }

        let helperTextSizes = helperWords.map {
            estimatedTextSize(for: $0.word, fontSize: helperFontSize)
        }
        let rowCount = Int((Double(helperWords.count) / 2.0).rounded(.up))
        let helperGapY = max(8, helperFontSize * 0.42)
        let helperStartY = min(
            mainRect.maxY + max(12, helperFontSize * 0.45),
            region.maxY - Double(rowCount) * helperTextSizes[0].height
                - Double(max(rowCount - 1, 0)) * helperGapY
        )

        for index in helperWords.indices {
            let size = helperTextSizes[index]
            let row = index / 2
            let isSingleLastItem = helperWords.count % 2 == 1
                && index == helperWords.count - 1
            let columnPosition = helperColumnPosition(
                index: index,
                singleLastItem: isSingleLastItem
            )
            let centerX = region.minX + region.width * columnPosition
            let rect = CoreRect(
                x: centerX - size.width / 2,
                y: helperStartY + Double(row) * (size.height + helperGapY),
                width: size.width,
                height: size.height
            ).clamped(to: region)

            placements.append(
                makePlacement(
                    word: helperWords[index].word,
                    rect: rect,
                    fontSize: helperFontSize,
                    depth: 0.0,
                    opacity: 0.88
                )
            )
        }

        return placements
    }

    private func helperColumnPosition(index: Int, singleLastItem: Bool) -> Double {
        if singleLastItem {
            return 0.50
        }

        return index % 2 == 0 ? 0.32 : 0.68
    }

    private func fontSize(base: Double, minimum: Double, scale: Double) -> Double {
        max(minimum * scale, base * scale)
    }

    private func estimatedTextSize(for word: String, fontSize: Double) -> CoreSize {
        let width = max(fontSize * 1.5, Double(word.count) * fontSize * 0.58)
        return CoreSize(width: width, height: fontSize * 1.18)
    }

    private func anchoredX(
        rectWidth: Double,
        in region: CoreRect,
        anchor: LayoutAnchor
    ) -> Double {
        switch anchor {
        case .leading:
            return region.minX + region.width * 0.12
        case .center:
            return region.center.x - rectWidth / 2
        case .trailing:
            return region.maxX - region.width * 0.12 - rectWidth
        }
    }

    private func makePlacement(
        word: String,
        rect: CoreRect,
        fontSize: Double,
        depth: Double,
        opacity: Double
    ) -> LayoutWordPlacement {
        LayoutWordPlacement(
            word: word,
            rect: rect,
            baseline: CorePoint(
                x: rect.minX,
                y: rect.minY + fontSize * 0.88
            ),
            fontSize: fontSize,
            depth: depth,
            opacity: opacity
        )
    }

    private func isValid(
        placements: [LayoutWordPlacement],
        displayRect: CoreRect,
        subjectRects: [CoreRect]
    ) -> Bool {
        placements.allSatisfy { displayRect.contains($0.rect) }
            && !placements.contains { placement in
                subjectRects.contains { placement.rect.intersects($0) }
            }
            && !hasWordOverlap(placements)
    }

    private func hasWordOverlap(_ placements: [LayoutWordPlacement]) -> Bool {
        for leftIndex in placements.indices {
            for rightIndex in placements.indices where rightIndex > leftIndex {
                if placements[leftIndex].rect.intersects(placements[rightIndex].rect) {
                    return true
                }
            }
        }

        return false
    }

    private func score(
        placements: [LayoutWordPlacement],
        displayRect: CoreRect,
        region: RegionChoice,
        analysis: ImageAnalysis
    ) -> Double {
        let textArea = placements.reduce(0) { $0 + $1.rect.area }
        let displayArea = max(displayRect.area, 1)
        let textCoverage = textArea / displayArea
        let calmScore = max(0, 1 - textCoverage * 8)
        let hotspotPenalty = placements.reduce(0) { partialResult, placement in
            partialResult + analysis.brightnessHotspots.reduce(0) { hotspotScore, hotspot in
                hotspotScore + (placement.rect.intersects(hotspot) ? 0.03 : 0)
            }
        }

        return 0.35
            + 0.25
            + 0.20
            + region.preference.score * 0.12
            + calmScore * 0.08
            - hotspotPenalty
    }

    private func makeDepthMode(for analysis: ImageAnalysis) -> LayoutDepthMode {
        guard analysis.maskConfidence >= reliableMaskThreshold else {
            return .foregroundOnly
        }

        if !analysis.depthHints.isEmpty {
            return .depthAware
        }

        return .foregroundAware
    }
}

private struct RegionChoice {
    var rect: CoreRect
    var preference: RegionPreference
}

private enum RegionPreference {
    case lowDetail
    case safeText
    case fallback

    var score: Double {
        switch self {
        case .lowDetail:
            return 1.0
        case .safeText:
            return 0.86
        case .fallback:
            return 0.70
        }
    }
}

private enum LayoutAnchor: CaseIterable {
    case center
    case leading
    case trailing
}

private extension CoreRect {
    var minX: Double { origin.x }
    var minY: Double { origin.y }
    var maxX: Double { origin.x + size.width }
    var maxY: Double { origin.y + size.height }
    var width: Double { size.width }
    var height: Double { size.height }
    var area: Double { max(width, 0) * max(height, 0) }
    var center: CorePoint {
        CorePoint(x: minX + width / 2, y: minY + height / 2)
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

    func clamped(to bounds: CoreRect) -> CoreRect {
        let clampedWidth = min(max(width, 0), max(bounds.width, 0))
        let clampedHeight = min(max(height, 0), max(bounds.height, 0))
        let clampedX = min(max(minX, bounds.minX), bounds.maxX - clampedWidth)
        let clampedY = min(max(minY, bounds.minY), bounds.maxY - clampedHeight)

        return CoreRect(
            x: clampedX,
            y: clampedY,
            width: clampedWidth,
            height: clampedHeight
        )
    }
}
