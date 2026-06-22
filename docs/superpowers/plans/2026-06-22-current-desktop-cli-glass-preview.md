# Current Desktop CLI Glass Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建“读取当前桌面 -> CLI 生成词卡 -> 玻璃风合成预览 -> 用户确认 Apply”的最小可用闭环。

**Architecture:** 在 `RuralWallpaperCore` 中新增当前桌面源、CLI 词卡 Provider 和玻璃风渲染接口；在 `RuralWallpaperApp` 中新增预览状态和预览窗口。保留旧 Unsplash/Provider 代码，但菜单主流程切换到新的本机闭环。

**Tech Stack:** Swift 6、SwiftUI、AppKit、CoreGraphics、Foundation `Process`、XCTest。

---

## Task 1: CLI 词卡 Provider

**Files:**
- Create: `Sources/RuralWallpaperCore/Provider/CLIWordProvider.swift`
- Test: `Tests/RuralWallpaperCoreTests/CLIWordProviderTests.swift`

- [ ] 写失败测试：合法 JSON 可解析为 3-5 个 `VocabularyItem`。
- [ ] 写失败测试：非 JSON 输出返回明确错误。
- [ ] 实现 JSON 解析和最小 `Process` 调用封装。
- [ ] 运行 `swift test --filter CLIWordProviderTests`。

## Task 2: 当前桌面壁纸源

**Files:**
- Create: `Sources/RuralWallpaperCore/Source/CurrentDesktopSource.swift`
- Test: `Tests/RuralWallpaperCoreTests/CurrentDesktopSourceTests.swift`

- [ ] 写失败测试：能从注入的桌面 URL 复制工作副本。
- [ ] 写失败测试：缺失 URL 时抛出可读错误。
- [ ] 实现 `CurrentDesktopSource` 和可注入 resolver。
- [ ] 运行 `swift test --filter CurrentDesktopSourceTests`。

## Task 3: 玻璃风渲染

**Files:**
- Modify: `Sources/RuralWallpaperCore/Render/CoreGraphicsRenderEngine.swift`
- Test: `Tests/RuralWallpaperCoreTests/RenderEngineTests.swift`

- [ ] 写失败测试：给定输入图片和词卡后输出同尺寸文件。
- [ ] 实现玻璃面板、文字、阴影和安全位置。
- [ ] 运行 `swift test --filter RenderEngineTests`。

## Task 4: 预览工作流

**Files:**
- Modify: `Sources/RuralWallpaperApp/AppContainer.swift`
- Create: `Sources/RuralWallpaperApp/Preview/WallpaperPreviewView.swift`
- Create: `Sources/RuralWallpaperApp/Preview/WallpaperPreviewWindowController.swift`
- Modify: `Sources/RuralWallpaperApp/MenuBar/MenuBarController.swift`
- Test: `Tests/RuralWallpaperAppTests/AppContainerTests.swift`

- [ ] 写失败测试：生成预览不会调用桌面 setter。
- [ ] 写失败测试：Apply 才调用桌面 setter。
- [ ] 实现 `generateGlassPreview()` 和 `applyPreview()`。
- [ ] 菜单新增 `Generate Preview`。
- [ ] 预览窗口显示图片、词卡、`Apply`、`Regenerate`、`Cancel`。

## Task 5: 文档、验证和打包

**Files:**
- Modify: `README.md`
- Modify: `docs/manual-verification.md`

- [ ] 更新 README 主流程。
- [ ] 运行 `swift test`。
- [ ] 运行 `swift build -c release`。
- [ ] 生成新的 `.app` 和 `.zip` 测试包。
