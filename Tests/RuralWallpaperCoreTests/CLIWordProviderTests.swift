import Foundation
import XCTest
@testable import RuralWallpaperCore

final class CLIWordProviderTests: XCTestCase {
    func testParsesVocabularyItemsFromJSONOutput() throws {
        let output = """
        {
          "words": [
            {
              "word": "tranquil",
              "partOfSpeech": "adjective",
              "zhDefinition": "宁静的",
              "example": "The desktop feels tranquil after sunset.",
              "difficulty": 3,
              "sourceReason": "The wallpaper has a calm evening mood."
            },
            {
              "word": "ridge",
              "partOfSpeech": "noun",
              "zhDefinition": "山脊",
              "example": "A ridge fades into the mist.",
              "difficulty": 2,
              "sourceReason": "The image contains distant mountains."
            },
            {
              "word": "glow",
              "partOfSpeech": "noun",
              "zhDefinition": "微光",
              "example": "A soft glow spreads across the sky.",
              "difficulty": 2,
              "sourceReason": "The wallpaper has warm light."
            }
          ]
        }
        """

        let words = try CLIWordProvider.parseWords(from: output)

        XCTAssertEqual(words.map(\.word), ["tranquil", "ridge", "glow"])
        XCTAssertEqual(words.first?.zhDefinition, "宁静的")
    }

    func testParsesJSONInsideMarkdownFence() throws {
        let output = """
        Here is the JSON:

        ```json
        {
          "words": [
            {
              "word": "meadow",
              "partOfSpeech": "noun",
              "zhDefinition": "草地",
              "example": "The meadow looks fresh in the morning.",
              "difficulty": 2,
              "sourceReason": "The wallpaper shows open grass."
            },
            {
              "word": "cottage",
              "partOfSpeech": "noun",
              "zhDefinition": "小屋",
              "example": "A cottage stands near the trees.",
              "difficulty": 2,
              "sourceReason": "A small house appears in the scene."
            },
            {
              "word": "mist",
              "partOfSpeech": "noun",
              "zhDefinition": "薄雾",
              "example": "Mist softens the distant hills.",
              "difficulty": 2,
              "sourceReason": "The background looks hazy."
            }
          ]
        }
        ```
        """

        let words = try CLIWordProvider.parseWords(from: output)

        XCTAssertEqual(words.map(\.word), ["meadow", "cottage", "mist"])
    }

    func testPromptRequestsConfiguredWordCount() {
        let imageURL = URL(fileURLWithPath: "/tmp/wallpaper.heic")

        let prompt = CLIWordProvider.prompt(for: imageURL, targetCount: 12)

        XCTAssertTrue(prompt.contains("输出 12 个"))
        XCTAssertTrue(prompt.contains("exactly 12"))
    }

    func testParseWordsAcceptsConfiguredCount() throws {
        let output = makeWordsJSON(count: 6)

        let words = try CLIWordProvider.parseWords(from: output, expectedCount: 6)

        XCTAssertEqual(words.count, 6)
    }

    func testParseWordsRejectsMismatchedConfiguredCount() {
        let output = makeWordsJSON(count: 5)

        XCTAssertThrowsError(
            try CLIWordProvider.parseWords(from: output, expectedCount: 6)
        ) { error in
            XCTAssertEqual(error as? CLIWordProviderError, .invalidWordCount(5))
        }
    }

    func testRejectsNonJSONOutputWithReadableError() {
        XCTAssertThrowsError(
            try CLIWordProvider.parseWords(from: "not json")
        ) { error in
            XCTAssertEqual(error as? CLIWordProviderError, .invalidJSON)
        }
    }

    func testDefaultPathIncludesNVMNodeBinsFromHomeDirectory() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CLIWordProviderTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let nodeBinDirectory = tempDirectory
            .appendingPathComponent(".nvm/versions/node/v22.21.0/bin", isDirectory: true)
        try FileManager.default.createDirectory(
            at: nodeBinDirectory,
            withIntermediateDirectories: true
        )
        let nodeURL = nodeBinDirectory.appendingPathComponent("node")
        try Data("#!/bin/sh\n".utf8).write(to: nodeURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: nodeURL.path
        )

        let path = CLIWordProvider.defaultPath(environment: [
            "HOME": tempDirectory.path,
            "PATH": "/usr/bin:/bin"
        ])

        let pathComponents = path
            .split(separator: ":")
            .map { URL(fileURLWithPath: String($0)).resolvingSymlinksInPath().path }
        XCTAssertTrue(pathComponents.contains(nodeBinDirectory.resolvingSymlinksInPath().path))
    }

    func testCodexInvocationTerminatesImageArgumentsBeforePrompt() {
        let imageURL = URL(fileURLWithPath: "/tmp/wallpaper.heic")
        let prompt = "Return JSON only."
        let provider = CLIWordProvider(command: .codex)

        let invocation = provider.invocation(prompt: prompt, imageURL: imageURL)

        let imageIndex = invocation.firstIndex(of: "--image")
        XCTAssertEqual(imageIndex.map { invocation[invocation.index(after: $0)] }, imageURL.path)
        XCTAssertTrue(invocation.contains("--"))
        XCTAssertEqual(invocation.suffix(2), ["--", prompt])
    }

    func testMissingCodexErrorIncludesInstallHint() {
        let error = CLIWordProviderError.commandNotInstalled(command: .codex)

        XCTAssertEqual(
            error.errorDescription,
            "未安装 Codex CLI。请先安装并登录 codex，然后重试。"
        )
    }

    func testExecutableResolverReturnsNilWhenCommandIsNotOnPath() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CLIWordProviderPathTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        XCTAssertNil(
            CLIWordProvider.executablePath(
                named: "codex",
                searchPath: tempDirectory.path
            )
        )
    }

    func testCodexRunnerDrainsLargeStderrWhileWaitingForOutput() async throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        try writeExecutable(
            named: "codex",
            in: tempDirectory,
            script: """
            #!/bin/sh
            i=0
            while [ "$i" -lt 2500 ]; do
              printf 'codex progress line %04d abcdefghijklmnopqrstuvwxyz0123456789\\n' "$i" >&2
              i=$((i + 1))
            done
            cat <<'JSON'
            {"words":[{"word":"meadow","partOfSpeech":"noun","zhDefinition":"草地","example":"The meadow is calm.","difficulty":2,"sourceReason":"The image shows grass."},{"word":"ridge","partOfSpeech":"noun","zhDefinition":"山脊","example":"A ridge fades away.","difficulty":2,"sourceReason":"The image has hills."},{"word":"glow","partOfSpeech":"noun","zhDefinition":"微光","example":"A glow lights the scene.","difficulty":2,"sourceReason":"The image has light."}]}
            JSON
            """
        )
        let imageURL = tempDirectory.appendingPathComponent("image.png")
        try Data("image".utf8).write(to: imageURL)
        let provider = CLIWordProvider(
            command: .codex,
            environment: [
                "PATH": tempDirectory.path,
                "HOME": tempDirectory.path
            ],
            timeoutSeconds: 5
        )

        let words = try await provider.extractWords(from: imageURL, targetCount: 3)

        XCTAssertEqual(words.map(\.word), ["meadow", "ridge", "glow"])
    }

    func testCodexRunnerTimesOutAndReportsReadableError() async throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let logs = ThreadSafeLog()
        try writeExecutable(
            named: "codex",
            in: tempDirectory,
            script: """
            #!/bin/sh
            i=0
            while true; do
              printf 'waiting for model %04d\\n' "$i" >&2
              i=$((i + 1))
              sleep 0.01
            done
            """
        )
        let imageURL = tempDirectory.appendingPathComponent("image.png")
        try Data("image".utf8).write(to: imageURL)
        let provider = CLIWordProvider(
            command: .codex,
            environment: [
                "PATH": tempDirectory.path,
                "HOME": tempDirectory.path
            ],
            timeoutSeconds: 0.5,
            logHandler: { logs.append($0) }
        )

        do {
            _ = try await provider.extractWords(from: imageURL, targetCount: 3)
            XCTFail("Expected timeout")
        } catch {
            XCTAssertEqual(
                error as? CLIWordProviderError,
                .commandTimedOut(command: .codex, timeoutSeconds: 0.5)
            )
            let logText = logs.text
            XCTAssertTrue(logText.contains("cli.timeout command=codex"))
            XCTAssertTrue(logText.contains("durationSeconds="))
            XCTAssertTrue(logText.contains("stdoutBytes=0"))
            XCTAssertTrue(logText.contains("stderrBytes="))
            XCTAssertTrue(logText.contains("stderrPreview=\"waiting for model"), logText)
        }
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CLIWordProviderProcessTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeExecutable(named name: String, in directory: URL, script: String) throws {
        let url = directory.appendingPathComponent(name)
        try Data(script.utf8).write(to: url)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: url.path
        )
    }

    private func makeWordsJSON(count: Int) -> String {
        let words = (0..<count).map { index in
            """
            {"word":"word\(index)","partOfSpeech":"noun","zhDefinition":"词\(index)","example":"Example \(index).","difficulty":2,"sourceReason":"Test word \(index)."}
            """
        }
        .joined(separator: ",")
        return #"{"words":["# + words + #"]}"#
    }
}

private final class ThreadSafeLog: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [String] = []

    func append(_ entry: String) {
        lock.lock()
        entries.append(entry)
        lock.unlock()
    }

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        return entries.joined(separator: "\n")
    }
}
