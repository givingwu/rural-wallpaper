import Darwin
import Foundation

public enum CLIWordCommand: String, Codable, CaseIterable, Equatable, Sendable {
    case codex
    case claude

    public var displayName: String {
        switch self {
        case .codex:
            return "Codex"
        case .claude:
            return "Claude Code"
        }
    }
}

public enum CLIWordProviderError: Error, Equatable, LocalizedError, Sendable {
    case invalidJSON
    case invalidWordCount(Int)
    case commandNotInstalled(command: CLIWordCommand)
    case commandTimedOut(command: CLIWordCommand, timeoutSeconds: TimeInterval)
    case commandFailed(command: String, exitCode: Int32, stderr: String)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "AI CLI did not return valid vocabulary JSON."
        case .invalidWordCount(let count):
            return "AI CLI returned \(count) words; expected 3...5."
        case .commandNotInstalled(let command):
            return "未安装 \(command.displayName) CLI。请先安装并登录 \(command.rawValue)，然后重试。"
        case .commandTimedOut(let command, let timeoutSeconds):
            return "\(command.displayName) CLI 执行超过 \(Self.formatSeconds(timeoutSeconds)) 秒，已停止本次生成。请稍后重试，或切换更快的 CLI。"
        case .commandFailed(let command, let exitCode, let stderr):
            let message = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if message.isEmpty {
                return "\(command) exited with code \(exitCode)."
            }
            return "\(command) exited with code \(exitCode): \(message)"
        }
    }

    private static func formatSeconds(_ value: TimeInterval) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.001 {
            return "\(Int(rounded))"
        }

        return String(format: "%.1f", value)
    }
}

public protocol ImageFileWordProvider: Sendable {
    func extractWords(from imageURL: URL) async throws -> [VocabularyItem]
}

public struct CLIWordProvider: ImageFileWordProvider {
    public var command: CLIWordCommand
    public var model: String?
    public var workingDirectory: URL
    public var environment: [String: String]?
    public var timeoutSeconds: TimeInterval
    public var logHandler: (@Sendable (String) -> Void)?

    public init(
        command: CLIWordCommand = .codex,
        model: String? = nil,
        workingDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
        environment: [String: String]? = nil,
        timeoutSeconds: TimeInterval = 180,
        logHandler: (@Sendable (String) -> Void)? = nil
    ) {
        self.command = command
        self.model = model
        self.workingDirectory = workingDirectory
        self.environment = environment
        self.timeoutSeconds = timeoutSeconds
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
        let controller = CLIProcessController()
        return try await withTaskCancellationHandler {
            try await Task.detached(priority: .userInitiated) {
                try self.runProcess(
                    prompt: prompt,
                    imageURL: imageURL,
                    controller: controller
                )
            }.value
        } onCancel: {
            controller.cancel()
        }
    }

    private func runProcess(
        prompt: String,
        imageURL: URL,
        controller: CLIProcessController
    ) throws -> String {
        let invocation = self.invocation(prompt: prompt, imageURL: imageURL)
        logHandler?("cli.start command=\(command.rawValue) timeoutSeconds=\(timeoutSeconds) workingDirectory=\(workingDirectory.path) image=\(imageURL.path)")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = invocation
        process.currentDirectoryURL = workingDirectory

        var processEnvironment = environment ?? ProcessInfo.processInfo.environment
        processEnvironment["PATH"] = Self.defaultPath(environment: processEnvironment)
        process.environment = processEnvironment
        logHandler?("cli.path \(processEnvironment["PATH"] ?? "")")
        guard Self.executablePath(
            named: command.rawValue,
            searchPath: processEnvironment["PATH"] ?? ""
        ) != nil else {
            logHandler?("cli.missing command=\(command.rawValue)")
            throw CLIWordProviderError.commandNotInstalled(command: command)
        }

        let stdout = Pipe()
        let stderr = Pipe()
        let stdoutReader = PipeDataReader(fileHandle: stdout.fileHandleForReading)
        let stderrReader = PipeDataReader(fileHandle: stderr.fileHandleForReading)
        process.standardOutput = stdout
        process.standardError = stderr

        let exitSemaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            exitSemaphore.signal()
        }

        stdoutReader.start()
        stderrReader.start()

        let startedAt = Date()
        try process.run()
        controller.attach(process)
        logHandler?("cli.spawned command=\(command.rawValue) pid=\(process.processIdentifier)")

        let didExit = exitSemaphore.wait(timeout: Self.dispatchTime(after: timeoutSeconds)) == .success
        if !didExit {
            logHandler?("cli.timeout command=\(command.rawValue) pid=\(process.processIdentifier) timeoutSeconds=\(timeoutSeconds)")
            controller.terminate()
            if exitSemaphore.wait(timeout: Self.dispatchTime(after: 2)) == .timedOut {
                controller.kill()
                _ = exitSemaphore.wait(timeout: Self.dispatchTime(after: 1))
            }
            _ = stdoutReader.waitForData(timeoutSeconds: 1)
            _ = stderrReader.waitForData(timeoutSeconds: 1)
            throw CLIWordProviderError.commandTimedOut(
                command: command,
                timeoutSeconds: timeoutSeconds
            )
        }

        let stdoutData = stdoutReader.waitForData(timeoutSeconds: 2)
        let stderrData = stderrReader.waitForData(timeoutSeconds: 2)
        let output = String(data: stdoutData, encoding: .utf8) ?? ""
        let errorOutput = String(data: stderrData, encoding: .utf8) ?? ""
        let duration = Date().timeIntervalSince(startedAt)

        if controller.isCancelled {
            logHandler?("cli.cancelled command=\(command.rawValue) durationSeconds=\(Self.formatDuration(duration)) stdoutBytes=\(stdoutData.count) stderrBytes=\(stderrData.count)")
            throw CancellationError()
        }

        logHandler?("cli.exit command=\(command.rawValue) status=\(process.terminationStatus) durationSeconds=\(Self.formatDuration(duration)) stdoutBytes=\(stdoutData.count) stderrBytes=\(stderrData.count)")
        guard process.terminationStatus == 0 else {
            throw CLIWordProviderError.commandFailed(
                command: command.rawValue,
                exitCode: process.terminationStatus,
                stderr: errorOutput
            )
        }

        return output
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

    static func executablePath(
        named executableName: String,
        searchPath: String,
        fileManager: FileManager = .default
    ) -> String? {
        guard !executableName.isEmpty else {
            return nil
        }

        if executableName.contains("/") {
            return fileManager.isExecutableFile(atPath: executableName) ? executableName : nil
        }

        for directory in searchPath.split(separator: ":").map(String.init) where !directory.isEmpty {
            let candidate = URL(fileURLWithPath: directory)
                .appendingPathComponent(executableName)
                .path
            if fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        return nil
    }

    private static func dispatchTime(after seconds: TimeInterval) -> DispatchTime {
        .now() + .milliseconds(max(0, Int((seconds * 1_000).rounded(.up))))
    }

    private static func formatDuration(_ value: TimeInterval) -> String {
        String(format: "%.3f", value)
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

private final class CLIProcessController: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func attach(_ process: Process) {
        lock.lock()
        let shouldCancel = cancelled
        if !shouldCancel {
            self.process = process
        }
        lock.unlock()

        if shouldCancel {
            process.terminate()
        }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let process = process
        lock.unlock()

        process?.terminate()
    }

    func terminate() {
        lock.lock()
        let process = process
        lock.unlock()

        process?.terminate()
    }

    func kill() {
        lock.lock()
        let pid = process?.processIdentifier
        lock.unlock()

        if let pid {
            Darwin.kill(pid, SIGKILL)
        }
    }
}

private final class PipeDataReader: @unchecked Sendable {
    private let fileHandle: FileHandle
    private let lock = NSLock()
    private let finished = DispatchSemaphore(value: 0)
    private var data = Data()
    private var hasStarted = false

    init(fileHandle: FileHandle) {
        self.fileHandle = fileHandle
    }

    func start() {
        lock.lock()
        guard !hasStarted else {
            lock.unlock()
            return
        }
        hasStarted = true
        lock.unlock()

        let thread = Thread { [weak self] in
            guard let self else { return }
            let result = self.fileHandle.readDataToEndOfFile()
            self.lock.lock()
            self.data = result
            self.lock.unlock()
            self.finished.signal()
        }
        thread.name = "CLIWordProvider.pipe-reader"
        thread.start()
    }

    func waitForData(timeoutSeconds: TimeInterval) -> Data {
        _ = finished.wait(timeout: .now() + .milliseconds(max(0, Int((timeoutSeconds * 1_000).rounded(.up)))))
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}
