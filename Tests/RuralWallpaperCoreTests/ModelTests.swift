import XCTest
@testable import RuralWallpaperCore

final class ModelTests: XCTestCase {
    func testProviderConfigUsesSecretReference() {
        let config = makeProviderConfig()

        XCTAssertEqual(config.secretRef.account, "default")
        XCTAssertTrue(config.capabilities.contains(.vision))
    }

    func testProviderConfigEncodingContainsSecretReferenceWithoutCredentialFields() throws {
        let encoded = try JSONEncoder().encode(makeProviderConfig())
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        let secret = try XCTUnwrap(object["secretRef"] as? [String: Any])
        let encodedKeys = Set(collectKeys(from: object))
        let forbiddenKeys = [
            "api" + "Key",
            "API" + "Key",
            "api" + "_key"
        ]

        XCTAssertEqual(secret["account"] as? String, "default")
        XCTAssertEqual(secret["service"] as? String, "RuralWallpaper")
        XCTAssertTrue(encodedKeys.contains("secretRef"))
        forbiddenKeys.forEach { key in
            XCTAssertFalse(encodedKeys.contains(key))
        }
    }

    func testVocabularyRangeValidation() {
        let items = VocabularyItem.samples(count: 4)
        XCTAssertTrue((3...5).contains(items.count))
    }

    func testEvaluationPassesAboveThreshold() {
        let result = makeEvaluationResult(
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

    func testEvaluationFailsBelowAverageThreshold() {
        let result = makeEvaluationResult(
            readability: 0.4,
            sceneFit: 0.4,
            depthBelievability: 0.4,
            desktopCalmness: 0.4,
            wordRelevance: 0.4,
            noBadOcclusion: 1.0,
            textCorrectness: 1.0
        )

        XCTAssertFalse(result.passes(threshold: 0.75))
    }

    func testEvaluationFailsWhenTextCorrectnessIsTooLow() {
        let result = makeEvaluationResult(textCorrectness: 0.94)

        XCTAssertFalse(result.passes(threshold: 0.75))
    }

    func testEvaluationFailsWhenOcclusionScoreIsTooLow() {
        let result = makeEvaluationResult(noBadOcclusion: 0.74)

        XCTAssertFalse(result.passes(threshold: 0.75))
    }

    private func makeProviderConfig() -> ProviderConfig {
        ProviderConfig(
            id: "default",
            name: "Default",
            baseURL: URL(string: "https://api.example.com/v1")!,
            model: "vision-model",
            secretRef: SecretRef(service: "RuralWallpaper", account: "default"),
            headers: ["X-Test": "1"],
            capabilities: [.vision, .imageGeneration, .structuredOutput]
        )
    }

    private func makeEvaluationResult(
        readability: Double = 0.9,
        sceneFit: Double = 0.9,
        depthBelievability: Double = 0.9,
        desktopCalmness: Double = 0.9,
        wordRelevance: Double = 0.9,
        noBadOcclusion: Double = 0.95,
        textCorrectness: Double = 1.0,
        notes: String = "good"
    ) -> EvaluationResult {
        EvaluationResult(
            readability: readability,
            sceneFit: sceneFit,
            depthBelievability: depthBelievability,
            desktopCalmness: desktopCalmness,
            wordRelevance: wordRelevance,
            noBadOcclusion: noBadOcclusion,
            textCorrectness: textCorrectness,
            notes: notes
        )
    }

    private func collectKeys(from value: Any) -> [String] {
        if let dictionary = value as? [String: Any] {
            return dictionary.keys + dictionary.values.flatMap(collectKeys)
        }

        if let array = value as? [Any] {
            return array.flatMap(collectKeys)
        }

        return []
    }
}
