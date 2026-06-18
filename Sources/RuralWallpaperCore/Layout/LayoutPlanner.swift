public protocol LayoutPlanner: Sendable {
    func makeLayoutCandidates(
        display: DisplayTarget,
        analysis: ImageAnalysis,
        words: [VocabularyItem],
        maxCandidates: Int
    ) -> [LayoutPlan]
}
