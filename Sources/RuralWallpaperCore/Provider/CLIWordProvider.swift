import Foundation

public enum CLIWordCommand: String, Codable, CaseIterable, Equatable, Sendable {
    case codex
    case claude
}

public enum CLIWordProviderError: Error, Equatable, LocalizedError, Sendable {
    case invalidJSON
    case invalidWordCount(Int)
    case commandFailed(command: String, exitCode: Int32, stderr: String)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "AI CLI did not return valid vocabulary JSON."
        case .invalidWordCount(let count):
            return "AI CLI returned \(count) words; expected 3...5."
        case .commandFailed(let command, let exitCode, let stderr):
            let message = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if message.isEmpty {
                return "\(command) exited with code \(exitCode)."
            }
            return "\(command) exited with code \(exitCode): \(message)"
        }
    }
}

public protocol ImageFileWordProvider: Sendable {
    func extractWords(from imageURL: URL) async throws -> [VocabularyItem]
}

public struct CLIWordProvider: ImageFileWordProvider {
    public var command: CLIWordCommand
    public var model: String?
    public var workingDirectory: URL
    public var logHandler: (@Sendable (String) -> Void)?

    public init(
        command: CLIWordCommand = .codex,
        model: String? = nil,
        workingDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
        logHandler: (@Sendable (String) -> Void)? = nil
    ) {
        self.command = command
        self.model = model
        self.workingDirectory = workingDirectory
        self.logHandler = logHandler
    }

    public func extractWords(from imageURL: URL) async throws -> [VocabularyItem] {
        let prompt = Self.prompt(for: imageURL)
        let output = try await run(prompt: prompt, imageURL: imageURL)
        return try Self.parseWords(from: output)
    }

    public static func parseWords(from output: String) throws -> [VocabularyItem] {
        guard let jsonData = extractJSONObject(from: output).data(using: .utf8) else {
            throw CLIWordProviderError.invalidJSON
        }

        do {
            let response = try JSONDecoder().decode(WordExtractionResponse.self, from: jsonData)
            guard (3...5).contains(response.words.count) else {
                throw CLIWordProviderError.invalidWordCount(response.words.count)
            }
            return response.words
        } catch let error as CLIWordProviderError {
            throw error
        } catch {
            throw CLIWordProviderError.invalidJSON
        }
    }

    private func run(prompt: String, imageURL: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let invocation = self.invocation(prompt: prompt, imageURL: imageURL)
            self.logHandler?("cli.start command=\(command.rawValue) workingDirectory=\(workingDirectory.path) image=\(imageURL.path)")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = invocation
            process.currentDirectoryURL = workingDirectory

            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = Self.defaultPath(environment: environment)
            process.environment = environment
            self.logHandler?("cli.path \(environment["PATH"] ?? "")")

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            try process.run()
            self.logHandler?("cli.spawned command=\(command.rawValue)")
            process.waitUntilExit()

            let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: stdoutData, encoding: .utf8) ?? ""
            let errorOutput = String(data: stderrData, encoding: .utf8) ?? ""

            self.logHandler?("cli.exit command=\(command.rawValue) status=\(process.terminationStatus) stdoutBytes=\(stdoutData.count) stderrBytes=\(stderrData.count)")
            guard process.terminationStatus == 0 else {
                throw CLIWordProviderError.commandFailed(
                    command: command.rawValue,
                    exitCode: process.terminationStatus,
                    stderr: errorOutput
                )
            }

            return output
        }.value
    }

    func invocation(prompt: String, imageURL: URL) -> [String] {
        switch command {
        case .codex:
            var arguments = [
                "codex",
                "exec",
                "--skip-git-repo-check",
                "--ephemeral",
                "--sandbox",
                "read-only",
                "--image",
                imageURL.path
            ]
            if let model, !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                arguments.append(contentsOf: ["--model", model])
            }
            arguments.append("--")
            arguments.append(prompt)
            return arguments
        case .claude:
            var arguments = [
                "claude",
                "--print",
                "--output-format",
                "text"
            ]
            if let model, !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                arguments.append(contentsOf: ["--model", model])
            }
            arguments.append(prompt)
            return arguments
        }
    }

    private static func prompt(for imageURL: URL) -> String {
        """
        请观察这张 macOS 桌面壁纸并输出 3 到 5 个适合英语学习的英文词。

        图片路径：\(imageURL.path)

        规则：
        - 单词必须来自画面语义或氛围。
        - 优先常用、有画面感、适合桌面记忆的词。
        - 必须只输出 JSON，不要输出解释、Markdown 或额外文本。
        - JSON schema:
          {
            "words": [
              {
                "word": "tranquil",
                "partOfSpeech": "adjective",
                "zhDefinition": "宁静的",
                "example": "The lake feels tranquil at sunrise.",
                "difficulty": 3,
                "sourceReason": "The scene has calm water and soft light."
              }
            ]
          }
        """
    }

    private static func extractJSONObject(from output: String) -> String {
        if let fenced = extractFencedJSON(from: output) {
            return fenced
        }

        guard
            let start = output.firstIndex(of: "{"),
            let end = output.lastIndex(of: "}"),
            start <= end
        else {
            return output
        }

        return String(output[start...end])
    }

    private static func extractFencedJSON(from output: String) -> String? {
        guard let fenceStart = output.range(of: "```") else {
            return nil
        }

        let afterStart = output[fenceStart.upperBound...]
        let contentStart: String.Index
        if afterStart.lowercased().hasPrefix("json"),
           let newline = afterStart.firstIndex(where: \.isNewline) {
            contentStart = afterStart.index(after: newline)
        } else {
            contentStart = afterStart.startIndex
        }

        guard let fenceEnd = output[contentStart...].range(of: "```") else {
            return nil
        }

        return String(output[contentStart..<fenceEnd.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func defaultPath(environment: [String: String]) -> String {
        let home = environment["HOME"] ?? NSHomeDirectory()
        let additions = [
            "\(home)/.nvm/current/bin",
        ] + nvmVersionBinDirectories(home: home) + [
            "\(home)/.volta/bin",
            "\(home)/.asdf/shims",
            "\(home)/.mise/shims",
            "\(home)/.fnm/current/bin",
            "\(home)/.local/share/pnpm",
            "\(home)/.local/bin",
            "/opt/homebrew/opt/node/bin",
            "/opt/homebrew/opt/node@22/bin",
            "/opt/homebrew/opt/node@20/bin",
            "/opt/homebrew/bin",
            "/usr/local/opt/node/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        let existing = environment["PATH"] ?? ""
        let existingComponents = existing.split(separator: ":").map(String.init)
        var seen = Set<String>()
        return (existingComponents + additions)
            .filter { !$0.isEmpty && seen.insert($0).inserted }
            .joined(separator: ":")
    }

    private static func nvmVersionBinDirectories(home: String) -> [String] {
        let versionsDirectory = URL(fileURLWithPath: home)
            .appendingPathComponent(".nvm/versions/node", isDirectory: true)
        let versionURLs = (try? FileManager.default.contentsOfDirectory(
            at: versionsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return versionURLs
            .filter { url in
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
                let nodeURL = url.appendingPathComponent("bin/node")
                return values?.isDirectory == true
                    && FileManager.default.isExecutableFile(atPath: nodeURL.path)
            }
            .sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedDescending
            }
            .map {
                $0.appendingPathComponent("bin", isDirectory: true).path
            }
    }
}
