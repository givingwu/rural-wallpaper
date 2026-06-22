# Rural Wallpaper

Rural Wallpaper 是一个面向 macOS 的英语学习壁纸应用。目标是做一个轻量的菜单栏应用：从 Unsplash 获取高质量桌面壁纸，用 AI 识别图片语义并提取 3-5 个英文学习词；桌面保持干净原图，中文释义、例句和来源信息显示在程序内。

## 产品目标

- 原生 macOS 菜单栏应用，日常入口轻量。
- Unsplash 作为真实壁纸来源，避免 AI 生图质量不稳定。
- AI 只用于识图取词，不再生成壁纸。
- 支持 OpenAI-compatible Vision Provider 配置：`Base URL`、`Model`、`API Key`、可选 Headers。
- 支持 Unsplash Access Key 配置。
- 每块显示器独立获取壁纸、独立取词、独立历史记录。
- 桌面不叠加英文文案；英文词、中文释义、例句和来源信息放在应用内。

## MVP 架构

核心方案是 **Swift / SwiftUI 原生菜单栏 App + Provider Harness**。

主要模块：

- `MenuBarApp`：菜单栏状态、立即生成、暂停、历史、设置入口。
- `SettingsStore`：保存非敏感配置。
- `SecretStore`：API Key 存入 macOS Keychain。
- `ProviderRegistry`：管理可配置的 OpenAI-compatible Vision Provider。
- `SourceProvider`：抽象素材来源，真实路径默认使用 Unsplash。
- `WallpaperHarness`：编排取图、取词、写入本地文件、设置桌面和记录历史。
- `DisplayCoordinator`：为每个显示器独立创建任务。
- `RenderEngine`：本地合成最终壁纸。
- `HistoryStore`：保存生成结果、词汇详情、来源信息和失败原因。

## 核心流程

```text
Scheduler / Manual Trigger
  -> DisplayCoordinator
  -> WallpaperHarness per screen
  -> UnsplashSource
  -> semantic word extraction
  -> write clean source image locally
  -> macOS desktop wallpaper setter
  -> HistoryStore
```

## 文档

- 设计规格：[docs/superpowers/specs/2026-06-18-rural-wallpaper-mac-ai-design.md](docs/superpowers/specs/2026-06-18-rural-wallpaper-mac-ai-design.md)
- 实施计划：[docs/superpowers/plans/2026-06-18-rural-wallpaper-mac-ai-implementation.md](docs/superpowers/plans/2026-06-18-rural-wallpaper-mac-ai-implementation.md)
- Provider 配置：[docs/provider-setup.md](docs/provider-setup.md)
- 手工验收：[docs/manual-verification.md](docs/manual-verification.md)

## 开发环境

- macOS 14+
- Swift 6 / Xcode Command Line Tools

## 使用方式

运行测试：

```bash
swift test
```

启动菜单栏 App：

```bash
swift run RuralWallpaperApp
```

首次启动后可在菜单栏打开 `Settings`：

- 未配置真实 Provider 时，`Generate Now` 使用本地 mock preview flow：生成一张渐变乡村壁纸、提取 3-5 个英文词、写入 History，但不会直接替换桌面。
- Provider `Test Connection` 成功且配置 Unsplash Access Key 后，`Generate Now` 会从 Unsplash 获取图片，用 AI 识图取词，并使用 macOS 桌面设置接口应用干净原图。
- `History` 展示当前显示器最近记录、词汇、中文释义、例句、Unsplash 来源和失败原因。

## 当前状态

项目已完成 Swift Package MVP 闭环。当前能力包括：

- 原生 macOS 菜单栏入口、Settings 和 History 窗口。
- OpenAI-compatible Vision Provider 配置：`Base URL`、`Model`、`API Key`、可选 Headers。
- Unsplash Access Key 配置。
- API Key 和 Unsplash Access Key 通过 Keychain 保存，非敏感设置通过 UserDefaults 保存。
- 本地 mock preview flow，可在没有 API Key 时完成端到端取词和历史记录。
- 真实 Provider smoke path：`Test Connection` 成功后切换到 Unsplash + AI 识图链路。
- 每块显示器独立调度，支持显示器过滤、消失取消、快照变化重启。
- 真实产品路径直接设置 Unsplash 原图，不在壁纸上叠加英文内容。
- FileHistoryStore 按显示器读取最近记录，每屏默认保留 30 条，写入前阻止明显 API Key / Bearer Token 泄漏。
