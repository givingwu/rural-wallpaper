# Rural Wallpaper Mac AI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个可运行的 Swift / SwiftUI macOS 菜单栏 MVP，支持可配置 AI Provider、多显示器独立生成、语义取词、悬挂式排版、自动评分重试、历史记录和桌面壁纸设置。

**Architecture:** 先用 Swift Package 建立可测试核心库 `RuralWallpaperCore`，把 Provider、Source、Harness、Layout、Render、Display、History 都隔离成协议和小模块；再接 `RuralWallpaperApp` 原生菜单栏外壳。第一版开发运行方式是 `swift run RuralWallpaperApp`，后续再补正式 `.app` 打包。

**Tech Stack:** Swift 6.3、Swift Package Manager、Foundation、AppKit、SwiftUI、Security(Keychain)、XCTest、CoreGraphics。

---

## 0. 实施约束

- 所有业务逻辑先进入 `Sources/RuralWallpaperCore`，UI 只做编排和状态展示。
- 不引入第三方依赖，直到核心闭环跑通。
- 每个任务按 TDD：先写失败测试，再写最小实现。
- 每个任务完成后单独提交。
- API Key 不允许写入 `UserDefaults`、JSON 历史、日志或测试 fixture。
- 真实 Provider 调用只放在手工验收，自动测试全部使用 mock。
- 若某步命令因 macOS UI 权限或 sandbox 失败，记录失败原因，不绕过安全限制。

## 1. 目标文件结构

```text
Package.swift
Sources/
  RuralWallpaperApp/
    main.swift
    AppDelegate.swift
    AppContainer.swift
    MenuBar/
      MenuBarController.swift
      MenuBarState.swift
    Settings/
      SettingsWindowController.swift
      SettingsView.swift
      ProviderSettingsView.swift
      GenerationSettingsView.swift
      DisplaySettingsView.swift
    History/
      HistoryWindowController.swift
      HistoryView.swift
  RuralWallpaperCore/
    Models/
      ProviderConfig.swift
      DisplayTarget.swift
      VocabularyItem.swift
      LayoutPlan.swift
      EvaluationResult.swift
      GeneratedWallpaper.swift
      WallpaperJob.swift
      SourceAttribution.swift
    Settings/
      AppSettings.swift
      SettingsStore.swift
      UserDefaultsSettingsStore.swift
      SecretStore.swift
      KeychainSecretStore.swift
    Provider/
      HTTPClient.swift
      OpenAICompatibleProvider.swift
      ProviderRegistry.swift
      ProviderSchemas.swift
    Source/
      SourceProvider.swift
      AIImageSource.swift
      UnsplashSource.swift
    Layout/
      ImageAnalysis.swift
      LayoutPlanner.swift
      WordLayoutPlanner.swift
    Render/
      RenderEngine.swift
      CoreGraphicsRenderEngine.swift
    Harness/
      WallpaperHarness.swift
      WallpaperJobStateMachine.swift
    Display/
      DisplayProvider.swift
      NSScreenDisplayProvider.swift
      DesktopWallpaperSetter.swift
      NSWorkspaceDesktopWallpaperSetter.swift
      DisplayCoordinator.swift
    History/
      HistoryStore.swift
      FileHistoryStore.swift
Tests/
  RuralWallpaperCoreTests/
    ModelTests.swift
    SettingsStoreTests.swift
    OpenAICompatibleProviderTests.swift
    SourceProviderTests.swift
    LayoutPlannerTests.swift
    RenderEngineTests.swift
    WallpaperHarnessTests.swift
    DisplayCoordinatorTests.swift
    HistoryStoreTests.swift
Fixtures/
  README.md
```

## 2. 任务拆分

### Task 1: Scaffold Swift Package

**Files:**
- Create: `Package.swift`
- Create: `Sources/RuralWallpaperCore/RuralWallpaperCore.swift`
- Create: `Sources/RuralWallpaperApp/main.swift`
- Create: `Tests/RuralWallpaperCoreTests/SmokeTests.swift`
- Create: `Fixtures/README.md`

- [ ] **Step 1: 写失败测试**

创建 `Tests/RuralWallpaperCoreTests/SmokeTests.swift`：

```swift
import XCTest
@testable import RuralWallpaperCore

final class SmokeTests: XCTestCase {
    func testCoreModuleExposesVersion() {
        XCTAssertEqual(RuralWallpaperCore.version, "0.1.0")
    }
}
```

- [ ] **Step 2: 创建 Package.swift**

创建 `Package.swift`：

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RuralWallpaper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "RuralWallpaperCore", targets: ["RuralWallpaperCore"]),
        .executable(name: "RuralWallpaperApp", targets: ["RuralWallpaperApp"])
    ],
    targets: [
        .target(name: "RuralWallpaperCore"),
        .executableTarget(
            name: "RuralWallpaperApp",
            dependencies: ["RuralWallpaperCore"]
        ),
        .testTarget(
            name: "RuralWallpaperCoreTests",
            dependencies: ["RuralWallpaperCore"]
        )
    ]
)
```

- [ ] **Step 3: 写最小实现**

创建 `Sources/RuralWallpaperCore/RuralWallpaperCore.swift`：

```swift
public enum RuralWallpaperCore {
    public static let version = "0.1.0"
}
```

创建 `Sources/RuralWallpaperApp/main.swift`：

```swift
import AppKit

print("RuralWallpaperApp developer runner")
NSApplication.shared.terminate(nil)
```

创建 `Fixtures/README.md`：

```markdown
# Fixtures

测试夹具目录。不要存放真实 API Key。
```

- [ ] **Step 4: 运行测试**

Run: `swift test`

Expected: `Test Suite 'All tests' passed`

- [ ] **Step 5: 提交**

```bash
git add Package.swift Sources Tests Fixtures
git commit -m "chore: scaffold swift package"
```

### Task 2: Domain Models

**Files:**
- Create: `Sources/RuralWallpaperCore/Models/ProviderConfig.swift`
- Create: `Sources/RuralWallpaperCore/Models/DisplayTarget.swift`
- Create: `Sources/RuralWallpaperCore/Models/VocabularyItem.swift`
- Create: `Sources/RuralWallpaperCore/Models/LayoutPlan.swift`
- Create: `Sources/RuralWallpaperCore/Models/EvaluationResult.swift`
- Create: `Sources/RuralWallpaperCore/Models/GeneratedWallpaper.swift`
- Create: `Sources/RuralWallpaperCore/Models/WallpaperJob.swift`
- Create: `Sources/RuralWallpaperCore/Models/SourceAttribution.swift`
- Create: `Tests/RuralWallpaperCoreTests/ModelTests.swift`

- [ ] **Step 1: 写模型测试**

创建 `Tests/RuralWallpaperCoreTests/ModelTests.swift`：

```swift
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
```

- [ ] **Step 2: 实现 ProviderConfig 与 SecretRef**

`ProviderConfig` 必须只保存 `SecretRef`，不要出现 `apiKey` 字段。

```swift
public struct SecretRef: Codable, Equatable, Sendable {
    public let service: String
    public let account: String
}

public struct ProviderCapability: OptionSet, Codable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let vision = ProviderCapability(rawValue: 1 << 0)
    public static let imageGeneration = ProviderCapability(rawValue: 1 << 1)
    public static let structuredOutput = ProviderCapability(rawValue: 1 << 2)
}

public struct ProviderConfig: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public var name: String
    public var baseURL: URL
    public var model: String
    public var secretRef: SecretRef
    public var headers: [String: String]
    public var capabilities: ProviderCapability
}
```

- [ ] **Step 3: 实现词汇、评分、显示器和任务模型**

模型保持 `Codable`、`Equatable`、`Sendable`。`EvaluationResult.passes(threshold:)` 使用各项平均分，并要求 `textCorrectness >= 0.95`、`noBadOcclusion >= 0.75`。

- [ ] **Step 4: 运行测试**

Run: `swift test --filter ModelTests`

Expected: `ModelTests` passed

- [ ] **Step 5: 提交**

```bash
git add Sources/RuralWallpaperCore/Models Tests/RuralWallpaperCoreTests/ModelTests.swift
git commit -m "feat: add core domain models"
```

### Task 3: Settings Store and Secret Store

**Files:**
- Create: `Sources/RuralWallpaperCore/Settings/AppSettings.swift`
- Create: `Sources/RuralWallpaperCore/Settings/SettingsStore.swift`
- Create: `Sources/RuralWallpaperCore/Settings/UserDefaultsSettingsStore.swift`
- Create: `Sources/RuralWallpaperCore/Settings/SecretStore.swift`
- Create: `Sources/RuralWallpaperCore/Settings/KeychainSecretStore.swift`
- Create: `Tests/RuralWallpaperCoreTests/SettingsStoreTests.swift`

- [ ] **Step 1: 写设置测试**

测试要求：

- 默认刷新频率是每天一次。
- 每屏历史保留默认是 30。
- `UserDefaultsSettingsStore` 能 round-trip `AppSettings`。
- `SecretStore` mock 能保存和读取密钥。

- [ ] **Step 2: 定义 AppSettings**

```swift
public struct AppSettings: Codable, Equatable, Sendable {
    public var autoUpdateEnabled: Bool
    public var refreshIntervalHours: Int
    public var maxBackgroundAttempts: Int
    public var maxLayoutCandidates: Int
    public var minimumScore: Double
    public var historyLimitPerDisplay: Int
    public var preferredThemes: [String]
    public var enabledDisplayIDs: Set<String>

    public static let `default` = AppSettings(
        autoUpdateEnabled: false,
        refreshIntervalHours: 24,
        maxBackgroundAttempts: 3,
        maxLayoutCandidates: 5,
        minimumScore: 0.75,
        historyLimitPerDisplay: 30,
        preferredThemes: ["rural", "nature", "calm"],
        enabledDisplayIDs: []
    )
}
```

- [ ] **Step 3: 实现 SettingsStore**

`SettingsStore` 暴露 `load()` 和 `save(_:)`。`UserDefaultsSettingsStore` 接收 injected suite，测试使用独立 suite name，测试结束清理。

- [ ] **Step 4: 实现 SecretStore**

`SecretStore` 协议：

```swift
public protocol SecretStore: Sendable {
    func read(_ ref: SecretRef) throws -> String?
    func write(_ value: String, for ref: SecretRef) throws
    func delete(_ ref: SecretRef) throws
}
```

`KeychainSecretStore` 使用 Security framework 的 `SecItemAdd`、`SecItemCopyMatching`、`SecItemUpdate`、`SecItemDelete`。

- [ ] **Step 5: 运行测试**

Run: `swift test --filter SettingsStoreTests`

Expected: all tests pass

- [ ] **Step 6: 提交**

```bash
git add Sources/RuralWallpaperCore/Settings Tests/RuralWallpaperCoreTests/SettingsStoreTests.swift
git commit -m "feat: add settings and secret stores"
```

### Task 4: OpenAI-Compatible Provider

**Files:**
- Create: `Sources/RuralWallpaperCore/Provider/HTTPClient.swift`
- Create: `Sources/RuralWallpaperCore/Provider/ProviderSchemas.swift`
- Create: `Sources/RuralWallpaperCore/Provider/OpenAICompatibleProvider.swift`
- Create: `Sources/RuralWallpaperCore/Provider/ProviderRegistry.swift`
- Create: `Tests/RuralWallpaperCoreTests/OpenAICompatibleProviderTests.swift`

- [ ] **Step 1: 写 Provider 请求构造测试**

测试覆盖：

- Authorization header 来自 `SecretStore`。
- `baseURL` 与 endpoint 拼接正确。
- 自定义 Headers 被带上。
- 缺少 vision capability 时，视觉取词抛出明确错误。
- 响应 JSON 解析失败时返回 `ProviderError.invalidResponse`。

- [ ] **Step 2: 实现 HTTPClient 抽象**

```swift
public struct HTTPRequest: Sendable {
    public var url: URL
    public var method: String
    public var headers: [String: String]
    public var body: Data?
}

public struct HTTPResponse: Sendable {
    public var statusCode: Int
    public var data: Data
}

public protocol HTTPClient: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}
```

提供 `URLSessionHTTPClient` 和测试用 `MockHTTPClient`。

- [ ] **Step 3: 定义 Provider 输出 schema**

包括：

- `WordExtractionResponse`
- `ImageGenerationResponse`
- `ImageAnalysisResponse`
- `EvaluationResponse`

字段必须与规格中的词汇、布局和评分模型一一对应。

- [ ] **Step 4: 实现 OpenAICompatibleProvider**

接口：

```swift
public protocol AIProvider: Sendable {
    func generateImage(prompt: String, size: CGSize) async throws -> GeneratedSourceImage
    func extractWords(from image: Data, countRange: ClosedRange<Int>) async throws -> [VocabularyItem]
    func analyzeImage(_ image: Data, display: DisplayTarget) async throws -> ImageAnalysis
    func evaluate(renderedImage: Data, plan: LayoutPlan, words: [VocabularyItem]) async throws -> EvaluationResult
}
```

- [ ] **Step 5: 运行测试**

Run: `swift test --filter OpenAICompatibleProviderTests`

Expected: all tests pass with mock HTTP responses

- [ ] **Step 6: 提交**

```bash
git add Sources/RuralWallpaperCore/Provider Tests/RuralWallpaperCoreTests/OpenAICompatibleProviderTests.swift
git commit -m "feat: add openai compatible provider"
```

### Task 5: Source Providers

**Files:**
- Create: `Sources/RuralWallpaperCore/Source/SourceProvider.swift`
- Create: `Sources/RuralWallpaperCore/Source/AIImageSource.swift`
- Create: `Sources/RuralWallpaperCore/Source/UnsplashSource.swift`
- Create: `Tests/RuralWallpaperCoreTests/SourceProviderTests.swift`

- [ ] **Step 1: 写 SourceProvider 测试**

测试覆盖：

- `AIImageSource` 调用 `AIProvider.generateImage`。
- Provider 不支持图片生成时失败。
- `UnsplashSource` 生成的 attribution 包含 photographer、profileURL、downloadTrackingURL。
- `UnsplashSource` 不把 Unsplash 定义为默认来源。

- [ ] **Step 2: 定义 SourceProvider 协议**

```swift
public protocol SourceProvider: Sendable {
    var id: String { get }
    func makeSourceImage(for display: DisplayTarget, settings: AppSettings) async throws -> SourceImage
}

public struct SourceImage: Sendable, Equatable {
    public var imageData: Data
    public var attribution: SourceAttribution
    public var prompt: String?
}
```

- [ ] **Step 3: 实现 AIImageSource**

生成 prompt 时包含：

- 用户主题偏好。
- 显示器尺寸。
- “quiet desktop wallpaper, no text” 约束。
- 每屏随机 seed。

- [ ] **Step 4: 实现 UnsplashSource 骨架**

只实现请求构造、响应解析和 attribution 数据模型；真实网络下载用 `HTTPClient` mock 测试。不要实现完整浏览器 UI。

- [ ] **Step 5: 运行测试**

Run: `swift test --filter SourceProviderTests`

Expected: all tests pass

- [ ] **Step 6: 提交**

```bash
git add Sources/RuralWallpaperCore/Source Tests/RuralWallpaperCoreTests/SourceProviderTests.swift
git commit -m "feat: add wallpaper source providers"
```

### Task 6: Layout Planner

**Files:**
- Create: `Sources/RuralWallpaperCore/Layout/ImageAnalysis.swift`
- Create: `Sources/RuralWallpaperCore/Layout/LayoutPlanner.swift`
- Create: `Sources/RuralWallpaperCore/Layout/WordLayoutPlanner.swift`
- Create: `Tests/RuralWallpaperCoreTests/LayoutPlannerTests.swift`

- [ ] **Step 1: 写布局测试**

测试覆盖：

- 3-5 个词都能生成布局。
- 每个文字 rect 在显示器 bounds 内。
- 主词字号大于辅助词。
- 候选避开 `ImageAnalysis.subjectRects`。
- 当没有可靠 mask 时 `depthMode == .foregroundOnly`。

- [ ] **Step 2: 定义 ImageAnalysis**

包含：

- `subjectRects`
- `lowDetailRects`
- `horizonLines`
- `brightnessHotspots`
- `safeInsets`
- `maskConfidence`

- [ ] **Step 3: 实现 LayoutPlanner**

`WordLayoutPlanner` 输入 `DisplayTarget`、`ImageAnalysis`、`[VocabularyItem]`，输出最多 5 个 `LayoutPlan`。候选优先使用 `lowDetailRects`，没有时用屏幕上 30%-55% 的区域作为退化方案。

- [ ] **Step 4: 实现几何评分**

评分项：

- 不越界。
- 不覆盖主体。
- 靠近视觉锚点。
- 词之间不重叠。
- 保持桌面安静。

- [ ] **Step 5: 运行测试**

Run: `swift test --filter LayoutPlannerTests`

Expected: all tests pass

- [ ] **Step 6: 提交**

```bash
git add Sources/RuralWallpaperCore/Layout Tests/RuralWallpaperCoreTests/LayoutPlannerTests.swift
git commit -m "feat: add hanging word layout planner"
```

### Task 7: Render Engine

**Files:**
- Create: `Sources/RuralWallpaperCore/Render/RenderEngine.swift`
- Create: `Sources/RuralWallpaperCore/Render/CoreGraphicsRenderEngine.swift`
- Create: `Tests/RuralWallpaperCoreTests/RenderEngineTests.swift`

- [ ] **Step 1: 写渲染测试**

测试覆盖：

- 输出 PNG 尺寸等于 `DisplayTarget.pixelSize`。
- 输出不是空白图片。
- 所有文字 rect 在画布内。
- 输入背景尺寸不匹配时按 scale-to-fill 裁切。

- [ ] **Step 2: 定义 RenderEngine**

```swift
public protocol RenderEngine: Sendable {
    func render(background: Data, plan: LayoutPlan, display: DisplayTarget) throws -> RenderedWallpaper
}
```

- [ ] **Step 3: 实现 CoreGraphicsRenderEngine**

使用 CoreGraphics 绘制：

- 背景 scale-to-fill。
- 白色或近白文字。
- 轻阴影。
- 字体默认用系统粗体。
- 不绘制释义、卡片或标签。

- [ ] **Step 4: 添加测试 fixture 生成器**

测试里用 CoreGraphics 动态生成纯色或渐变 PNG，不从网络下载图片。

- [ ] **Step 5: 运行测试**

Run: `swift test --filter RenderEngineTests`

Expected: all tests pass

- [ ] **Step 6: 提交**

```bash
git add Sources/RuralWallpaperCore/Render Tests/RuralWallpaperCoreTests/RenderEngineTests.swift
git commit -m "feat: add core graphics render engine"
```

### Task 8: Wallpaper Harness and Retry State Machine

**Files:**
- Create: `Sources/RuralWallpaperCore/Harness/WallpaperJobStateMachine.swift`
- Create: `Sources/RuralWallpaperCore/Harness/WallpaperHarness.swift`
- Create: `Tests/RuralWallpaperCoreTests/WallpaperHarnessTests.swift`

- [ ] **Step 1: 写 Harness 测试**

测试覆盖：

- 成功路径：source -> words -> analysis -> layout -> render -> evaluate -> apply。
- 低分时先重排版。
- 布局候选耗尽后再重背景。
- 达到最大重试后失败且不调用 desktop setter。
- 单个 job 失败不会影响另一个 job。

- [ ] **Step 2: 实现 Job 状态机**

状态只能按规格顺序推进。非法状态跳转抛出 `WallpaperJobError.invalidTransition`。

- [ ] **Step 3: 实现 WallpaperHarness**

依赖注入：

- `SourceProvider`
- `AIProvider`
- `LayoutPlanner`
- `RenderEngine`
- `DesktopWallpaperSetter`
- `HistoryStore`
- `AppSettings`

- [ ] **Step 4: 实现重试策略**

默认：

- 背景最多 3 次。
- 每张背景最多 5 个布局候选。
- `EvaluationResult.passes(threshold:)` 为通过条件。

- [ ] **Step 5: 运行测试**

Run: `swift test --filter WallpaperHarnessTests`

Expected: all tests pass

- [ ] **Step 6: 提交**

```bash
git add Sources/RuralWallpaperCore/Harness Tests/RuralWallpaperCoreTests/WallpaperHarnessTests.swift
git commit -m "feat: add wallpaper harness"
```

### Task 9: Display Coordinator and Desktop Setter

**Files:**
- Create: `Sources/RuralWallpaperCore/Display/DisplayProvider.swift`
- Create: `Sources/RuralWallpaperCore/Display/NSScreenDisplayProvider.swift`
- Create: `Sources/RuralWallpaperCore/Display/DesktopWallpaperSetter.swift`
- Create: `Sources/RuralWallpaperCore/Display/NSWorkspaceDesktopWallpaperSetter.swift`
- Create: `Sources/RuralWallpaperCore/Display/DisplayCoordinator.swift`
- Create: `Tests/RuralWallpaperCoreTests/DisplayCoordinatorTests.swift`

- [ ] **Step 1: 写多显示器测试**

测试覆盖：

- 两块显示器创建两个独立 job。
- 禁用的 display 不生成。
- 单屏失败不影响另一屏。
- 屏幕变化后取消消失屏幕的任务。

- [ ] **Step 2: 定义 DisplayProvider**

```swift
public protocol DisplayProvider: Sendable {
    func currentDisplays() -> [DisplayTarget]
}
```

测试使用 `MockDisplayProvider`。

- [ ] **Step 3: 实现 NSScreenDisplayProvider**

用 `NSScreen.screens` 填充 `DisplayTarget`。`friendlyName` 初期可用 `localizedName` 或 fallback 到 frame 描述。

- [ ] **Step 4: 实现 DesktopWallpaperSetter**

```swift
public protocol DesktopWallpaperSetter: Sendable {
    func setWallpaper(fileURL: URL, for display: DisplayTarget) throws
}
```

`NSWorkspaceDesktopWallpaperSetter` 使用 `NSWorkspace.shared.setDesktopImageURL(_:for:options:)`。如果找不到匹配 `NSScreen`，抛出明确错误。

- [ ] **Step 5: 实现 DisplayCoordinator**

负责为每块启用显示器并发执行 `WallpaperHarness.run(display:)`。使用 task group，但限制同一显示器不重复并发。

- [ ] **Step 6: 运行测试**

Run: `swift test --filter DisplayCoordinatorTests`

Expected: all tests pass

- [ ] **Step 7: 提交**

```bash
git add Sources/RuralWallpaperCore/Display Tests/RuralWallpaperCoreTests/DisplayCoordinatorTests.swift
git commit -m "feat: add display coordination"
```

### Task 10: File History Store

**Files:**
- Create: `Sources/RuralWallpaperCore/History/HistoryStore.swift`
- Create: `Sources/RuralWallpaperCore/History/FileHistoryStore.swift`
- Create: `Tests/RuralWallpaperCoreTests/HistoryStoreTests.swift`

- [ ] **Step 1: 写历史测试**

测试覆盖：

- 写入成功记录。
- 写入失败记录。
- 按 display 分组读取。
- 每屏只保留最近 30 条。
- JSON 中不包含 API Key 或 `Bearer`。

- [ ] **Step 2: 定义 HistoryStore**

```swift
public protocol HistoryStore: Sendable {
    func append(_ record: GeneratedWallpaper) throws
    func recent(displayID: String, limit: Int) throws -> [GeneratedWallpaper]
}
```

- [ ] **Step 3: 实现 FileHistoryStore**

存储位置通过初始化参数注入。生产环境使用 App Support，测试使用临时目录。

- [ ] **Step 4: 添加敏感信息扫描**

写入前检查 JSON 字符串，若包含 `Bearer `、`apiKey`、`sk-` 等明显密钥形态，抛出 `HistoryStoreError.sensitiveDataDetected`。

- [ ] **Step 5: 运行测试**

Run: `swift test --filter HistoryStoreTests`

Expected: all tests pass

- [ ] **Step 6: 提交**

```bash
git add Sources/RuralWallpaperCore/History Tests/RuralWallpaperCoreTests/HistoryStoreTests.swift
git commit -m "feat: add file history store"
```

### Task 11: Menu Bar App Shell

**Files:**
- Modify: `Sources/RuralWallpaperApp/main.swift`
- Create: `Sources/RuralWallpaperApp/AppDelegate.swift`
- Create: `Sources/RuralWallpaperApp/AppContainer.swift`
- Create: `Sources/RuralWallpaperApp/MenuBar/MenuBarController.swift`
- Create: `Sources/RuralWallpaperApp/MenuBar/MenuBarState.swift`
- Create: `Sources/RuralWallpaperApp/Settings/SettingsWindowController.swift`
- Create: `Sources/RuralWallpaperApp/Settings/SettingsView.swift`
- Create: `Sources/RuralWallpaperApp/Settings/ProviderSettingsView.swift`
- Create: `Sources/RuralWallpaperApp/Settings/GenerationSettingsView.swift`
- Create: `Sources/RuralWallpaperApp/Settings/DisplaySettingsView.swift`
- Create: `Sources/RuralWallpaperApp/History/HistoryWindowController.swift`
- Create: `Sources/RuralWallpaperApp/History/HistoryView.swift`

- [ ] **Step 1: 写可测试 ViewModel 逻辑**

如 UI 逻辑复杂，先创建可测试的 `MenuBarState`，验证：

- `isGenerating` 时禁用重复生成。
- `Paused` 时自动更新不触发。
- 失败状态能展示最近错误摘要。

- [ ] **Step 2: 实现 AppDelegate**

`main.swift` 启动 `NSApplication` 并设置 `AppDelegate`：

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
```

- [ ] **Step 3: 实现 AppContainer**

集中创建核心依赖。第一版允许 mock provider 模式，以便无 API Key 时也能启动菜单栏。

- [ ] **Step 4: 实现 MenuBarController**

菜单项：

- 状态文本。
- `Generate Now`
- `Pause Auto Update`
- `History`
- `Settings`
- `Quit`

- [ ] **Step 5: 实现 Settings SwiftUI Views**

表单字段：

- Base URL
- Model
- API Key
- Headers
- Test Connection
- 刷新频率
- 最大重试
- 最低评分阈值
- 显示器启用列表

代码注释只解释关键逻辑，例如 Keychain 写入与明文不落盘。

- [ ] **Step 6: 实现 History SwiftUI View**

展示最近记录：

- 缩略图路径。
- 英文词。
- 中文释义。
- 例句。
- 评分。
- 失败原因。

- [ ] **Step 7: 手动运行**

Run: `swift run RuralWallpaperApp`

Expected:

- 菜单栏出现应用入口。
- Settings 和 History 能打开。
- Quit 能退出。

- [ ] **Step 8: 提交**

```bash
git add Sources/RuralWallpaperApp
git commit -m "feat: add native menu bar app shell"
```

### Task 12: End-to-End Mock Flow

**Files:**
- Modify: `Sources/RuralWallpaperApp/AppContainer.swift`
- Modify: `Sources/RuralWallpaperApp/MenuBar/MenuBarController.swift`
- Modify: `Sources/RuralWallpaperCore/Harness/WallpaperHarness.swift`
- Create: `Sources/RuralWallpaperCore/Provider/MockPreviewProvider.swift`
- Create: `Sources/RuralWallpaperCore/Source/MockSourceProvider.swift`
- Create: `Tests/RuralWallpaperCoreTests/EndToEndMockFlowTests.swift`

- [ ] **Step 1: 写端到端 mock 测试**

测试从 mock display 开始，生成一张临时壁纸文件，验证：

- desktop setter 被调用一次。
- history 写入一条成功记录。
- 词数在 3-5。
- 输出图片存在且可读。

- [ ] **Step 2: 添加开发预览 Provider**

`MockPreviewProvider` 返回固定词汇和固定高评分，不访问网络。

- [ ] **Step 3: 添加 MockSourceProvider**

动态生成一张简单渐变 PNG 作为背景，方便开发者无 API Key 体验完整菜单栏流程。

- [ ] **Step 4: 接入 Generate Now**

菜单栏 `Generate Now` 在未配置真实 Provider 时使用 mock flow，并把输出写到临时目录或 App Support 开发目录。

- [ ] **Step 5: 运行测试**

Run: `swift test --filter EndToEndMockFlowTests`

Expected: all tests pass

- [ ] **Step 6: 手动运行**

Run: `swift run RuralWallpaperApp`

Expected:

- 点击 `Generate Now` 后状态变成 Generating。
- 完成后 History 出现一条记录。
- 若启用真实 desktop setter，本机桌面被替换；若处于 mock setter，日志显示目标文件。

- [ ] **Step 7: 提交**

```bash
git add Sources Tests
git commit -m "feat: wire end-to-end mock wallpaper flow"
```

### Task 13: Real Provider Smoke Path

**Files:**
- Modify: `Sources/RuralWallpaperCore/Provider/OpenAICompatibleProvider.swift`
- Modify: `Sources/RuralWallpaperApp/Settings/ProviderSettingsView.swift`
- Modify: `Sources/RuralWallpaperApp/AppContainer.swift`
- Create: `docs/provider-setup.md`

- [ ] **Step 1: 补充 Provider setup 文档**

创建 `docs/provider-setup.md`，说明：

- Base URL 示例。
- Model 示例。
- API Key 存储到 Keychain。
- Provider 必须支持 vision、image generation、structured output。
- 不要提交 API Key。

- [ ] **Step 2: 实现 Test Connection**

设置页点击 `Test Connection`：

- 读取 Keychain API Key。
- 发送最小模型请求或 capability probe。
- 成功显示 provider 可用能力。
- 失败显示错误摘要。

- [ ] **Step 3: 实现真实 Provider 开关**

当设置完整且测试通过后，`AppContainer` 使用真实 `OpenAICompatibleProvider`；否则保持 mock mode。

- [ ] **Step 4: 手工验收**

Run: `swift run RuralWallpaperApp`

Expected:

- 配置真实 Provider 后 Test Connection 成功。
- Generate Now 能触发真实生成。
- API Key 不出现在任何 `.json`、history 或日志中。

- [ ] **Step 5: 提交**

```bash
git add Sources docs/provider-setup.md
git commit -m "feat: add real provider smoke path"
```

### Task 14: Documentation and Verification

**Files:**
- Modify: `README.md`
- Modify: `.gitignore`
- Create: `docs/manual-verification.md`

- [ ] **Step 1: 更新 README**

增加：

- 开发环境要求。
- `swift test`。
- `swift run RuralWallpaperApp`。
- MVP 功能状态。
- API Key 安全说明。

- [ ] **Step 2: 写手工验收清单**

`docs/manual-verification.md` 包含：

- mock flow 验收。
- real provider smoke 验收。
- 多显示器验收。
- 桌面回滚验收。
- Keychain/敏感信息验收。

- [ ] **Step 3: 运行全量测试**

Run: `swift test`

Expected: all tests pass

- [ ] **Step 4: 检查敏感信息**

Run: `rg -n "sk-|Bearer |apiKey|API_KEY" .`

Expected: 只允许命中文档中的警示文字，不允许命中真实密钥。

- [ ] **Step 5: 检查工作区**

Run: `git status --short`

Expected: 只显示本任务预期文档变更，或为空。

- [ ] **Step 6: 提交**

```bash
git add README.md .gitignore docs/manual-verification.md
git commit -m "docs: add development and verification guide"
```

## 3. 完成标准

完成全部任务后应满足：

- `swift test` 通过。
- `swift run RuralWallpaperApp` 能启动菜单栏应用。
- 无 API Key 时 mock flow 可完整跑通。
- 配置真实 Provider 后可执行真实 smoke path。
- Generate Now 能为启用显示器生成并记录历史。
- 单屏失败不影响其它屏幕。
- 历史 JSON 不包含明文密钥。
- README 和手工验收文档覆盖开发、配置、运行和验证方式。

## 4. 风险与处理

- SwiftPM 可运行菜单栏开发版本，但正式 `.app` 打包可能需要后续 Xcode project 或打包脚本；本计划先不处理分发。
- `NSWorkspace.setDesktopImageURL` 在不同 macOS 权限和 sandbox 下可能行为不同；实现时必须保留 mock setter 和失败回滚。
- 真实 Provider 的 image generation API 兼容性差异较大；Provider 层必须把请求构造和响应解析集中管理，避免散落到 Harness。
- 多显示器名称和稳定 ID 在 macOS 上可能不完全可靠；第一版允许使用 frame、localizedName 和 NSScreen 描述组合生成 display ID，后续再优化。
