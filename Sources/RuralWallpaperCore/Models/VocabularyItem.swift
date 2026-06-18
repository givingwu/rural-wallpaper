public struct VocabularyItem: Codable, Equatable, Sendable {
    public var word: String
    public var partOfSpeech: String
    public var zhDefinition: String
    public var example: String
    public var difficulty: Int
    public var sourceReason: String

    public init(
        word: String,
        partOfSpeech: String,
        zhDefinition: String,
        example: String,
        difficulty: Int,
        sourceReason: String
    ) {
        self.word = word
        self.partOfSpeech = partOfSpeech
        self.zhDefinition = zhDefinition
        self.example = example
        self.difficulty = difficulty
        self.sourceReason = sourceReason
    }

    public static func samples(count: Int) -> [VocabularyItem] {
        let clampedCount = min(max(count, 3), 5)
        return Array(sampleItems.prefix(clampedCount))
    }

    private static let sampleItems: [VocabularyItem] = [
        VocabularyItem(
            word: "meadow",
            partOfSpeech: "noun",
            zhDefinition: "草地",
            example: "A quiet meadow stretches beyond the cottage.",
            difficulty: 2,
            sourceReason: "Open rural grassland in the scene."
        ),
        VocabularyItem(
            word: "lantern",
            partOfSpeech: "noun",
            zhDefinition: "灯笼",
            example: "A lantern glows near the wooden porch.",
            difficulty: 2,
            sourceReason: "Warm light source in the foreground."
        ),
        VocabularyItem(
            word: "harvest",
            partOfSpeech: "noun",
            zhDefinition: "收获",
            example: "The harvest season colors the field gold.",
            difficulty: 3,
            sourceReason: "Field crops suggest seasonal farming."
        ),
        VocabularyItem(
            word: "ridge",
            partOfSpeech: "noun",
            zhDefinition: "山脊",
            example: "A soft ridge fades into the evening sky.",
            difficulty: 3,
            sourceReason: "Layered hills create distant depth."
        ),
        VocabularyItem(
            word: "tranquil",
            partOfSpeech: "adjective",
            zhDefinition: "宁静的",
            example: "The village feels tranquil after sunset.",
            difficulty: 4,
            sourceReason: "Overall calm desktop mood."
        )
    ]
}
