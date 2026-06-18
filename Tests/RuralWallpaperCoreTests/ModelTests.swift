import XCTest
@testable import RuralWallpaperCore

final class ModelTests: XCTestCase {
    func testProviderConfigDoesNotStorePlainAPIKey() {
        let config = ProviderConfig(
            id: "default",
            name: "Default",
            baseURL: URL(string: "https://api.example.com/v1")!,
            model: "vision-model",
            secretRef: SecretRef(service: "RuralWallpaper", account: "default"),
            headers: ["X-Test": "1"],
            capabilities: [.vision, .imageGeneration, .structuredOutput]
        )

        XCTAssertEqual(config.secretRef.account, "default")
        XCTAssertTrue(config.capabilities.contains(.vision))
    }

    func testVocabularyRangeValidation() {
        let items = VocabularyItem.samples(count: 4)
        XCTAssertTrue((3...5).contains(items.count))
    }

    func testEvaluationPassesAboveThreshold() {
        let result = EvaluationResult(
            readability: 0.9,
            sceneFit: 0.8,
            depthBelievability: 0.7,
            desktopCalmness: 0.85,
            wordRelevance: 0.9,
            noBadOcclusion: 0.95,
            textCorrectness: 1.0,
            notes: "good"
        )

        XCTAssertTrue(result.passes(threshold: 0.75))
    }
}
