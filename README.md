# Rural Wallpaper

Rural Wallpaper 是一个面向 macOS 的英语学习壁纸菜单栏应用。当前主流程很简单：读取你现有的桌面壁纸，用本机 Codex 或 Claude Code CLI 生成 3-5 个英文学习词，再把低透明度 iOS / Liquid Glass 风格英文词牌分散合成到图片上。应用会先展示预览，只有点击 `Apply` 后才会替换当前桌面壁纸。

## 产品目标

- 原生 macOS 菜单栏应用，入口轻量。
- 直接使用当前桌面壁纸，不再依赖 Unsplash。
- AI Provider 使用本机 `codex` 或 `claude` CLI，不在 App 中配置 API Key。
- 文案合成在本地完成，生成前后文件写入 `~/Library/Application Support/RuralWallpaper/`。
- 替换桌面前必须经过预览确认。

## MVP 架构

核心方案是 **Swift / SwiftUI 原生菜单栏 App + 本机 CLI 文案 Provider + CoreGraphics 渲染**。

主要模块：

- `MenuBarApp`：菜单栏状态、生成预览、设置和日志入口。
- `CurrentDesktopSource`：读取并复制当前桌面壁纸。
- `CLIWordProvider`：调用 `codex` 或 `claude` CLI，解析词卡 JSON。
- `CoreGraphicsRenderEngine`：本地合成低透明度、分散布局的英文玻璃词牌壁纸。
- `WallpaperPreviewWindowController`：展示预览，提供 `Apply`、`Regenerate`、`Cancel`。
- `NSWorkspaceDesktopWallpaperSetter`：用户确认后调用 macOS 桌面设置接口。
- `AppLogger`：写入执行顺序日志，便于定位失败步骤。
- `SettingsStore`：保存 CLI 选择等非敏感配置。

## 核心流程

```text
Generate Preview
  -> CurrentDesktopSource
  -> CLIWordProvider
  -> renderGlassOverlay
  -> Preview Window
  -> Apply
  -> macOS desktop wallpaper setter
```

## 文档

- 当前设计规格：[docs/superpowers/specs/2026-06-22-current-desktop-cli-glass-preview-design.md](docs/superpowers/specs/2026-06-22-current-desktop-cli-glass-preview-design.md)
- 当前实施计划：[docs/superpowers/plans/2026-06-22-current-desktop-cli-glass-preview.md](docs/superpowers/plans/2026-06-22-current-desktop-cli-glass-preview.md)
- CLI 配置：[docs/provider-setup.md](docs/provider-setup.md)
- 手工验收：[docs/manual-verification.md](docs/manual-verification.md)

## 开发环境

- macOS 14+
- Swift 6 / Xcode Command Line Tools
- 已登录可用的 `codex` 或 `claude` CLI

## 使用方式

运行测试：

```bash
swift test
```

启动菜单栏 App：

```bash
swift run RuralWallpaperApp
```

打包后的测试方式：

```bash
open dist/RuralWallpaper-*.app
```

操作流程：

1. 启动 App 后点击 macOS 菜单栏里的 Rural Wallpaper 图标。
2. 打开 `Settings -> Provider`，选择 `Codex` 或 `Claude`，点击 `Save`。
3. 点击菜单栏 `Generate Preview`。
4. 在预览窗口确认壁纸效果和词卡内容。
5. 点击 `Apply` 后才会替换当前桌面壁纸。

如果 Pap.er 等工具让 macOS 返回一个已经被删除的源图路径，`Generate Preview` 会先在同目录查找最近修改的可读图片作为兜底，并在日志中记录 `Current desktop wallpaper fallback: <filename>`。如果同目录也没有可用图片，可以点击 `Choose Image...` 选择一张实际存在的本地图片，后续仍然走同一套 CLI 取词、玻璃风合成和 Apply 流程。

菜单栏当前只保留主流程需要的入口：

- `Generate Preview`
- `Choose Image...`
- `Settings`
- `Open Logs`
- `Quit`

日志路径：

```bash
~/Library/Application Support/RuralWallpaper/rural-wallpaper.log
```

## 当前状态

当前能力包括：

- 原生 macOS 菜单栏入口、Settings 和 Preview 窗口。
- 当前桌面壁纸读取和工作副本复制。
- 当前桌面源文件缺失时，自动从同目录选择最近修改的本地图片兜底。
- Codex / Claude Code CLI 文案 Provider，解析 3-5 个英文词、中文释义和例句。
- 本地 CoreGraphics 玻璃风文案合成：壁纸只显示英文词和英文词性，中文释义和例句保留在 Preview 右侧词卡内。
- 预览确认后应用桌面，生成预览阶段不会替换现有壁纸。
- 菜单栏 `Open Logs` 可打开执行日志，日志包含 source、CLI、render、preview、apply 等步骤。
- 保留旧 OpenAI-compatible / Unsplash 代码和测试，但不再作为主流程展示。
