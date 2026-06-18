# Rural Wallpaper

Rural Wallpaper 是一个面向 macOS 的 AI 学习壁纸应用设计项目。目标是做一个轻量的菜单栏应用：自动生成高审美桌面壁纸，并把 3-5 个来自画面语义的英文单词以类似 iOS 26 锁屏时间的方式“悬挂”在壁纸上。

## 产品目标

- 原生 macOS 菜单栏应用，日常入口轻量。
- AI 生成壁纸优先，Unsplash 作为可选素材连接器。
- 支持 OpenAI-compatible Provider 配置：`Base URL`、`Model`、`API Key`、可选 Headers。
- 每块显示器独立生成壁纸、独立取词、独立排版。
- 桌面只显示英文单词；中文释义、例句、评分和历史记录放在应用内。
- 使用自动化 AI Loop：生成候选、视觉评分、自动重试、达标后设置桌面。

## MVP 架构

核心方案是 **Swift / SwiftUI 原生菜单栏 App + Provider Harness**。

主要模块：

- `MenuBarApp`：菜单栏状态、立即生成、暂停、历史、设置入口。
- `SettingsStore`：保存非敏感配置。
- `SecretStore`：API Key 存入 macOS Keychain。
- `ProviderRegistry`：管理可配置的 LLM/Image Provider。
- `SourceProvider`：抽象素材来源，默认 AI 生成，可扩展 Unsplash、本地目录、Pexels。
- `WallpaperHarness`：编排生成、取词、排版、渲染、评分、重试和设置桌面。
- `DisplayCoordinator`：为每个显示器独立创建任务。
- `RenderEngine`：本地合成最终壁纸。
- `HistoryStore`：保存生成结果、词汇详情、评分和失败原因。

## 核心流程

```text
Scheduler / Manual Trigger
  -> DisplayCoordinator
  -> WallpaperHarness per screen
  -> SourceProvider
  -> semantic word extraction
  -> layout planning
  -> local rendering
  -> visual evaluation
  -> macOS desktop wallpaper setter
  -> HistoryStore
```

## 文档

- 设计规格：[docs/superpowers/specs/2026-06-18-rural-wallpaper-mac-ai-design.md](docs/superpowers/specs/2026-06-18-rural-wallpaper-mac-ai-design.md)
- 实施计划：[docs/superpowers/plans/2026-06-18-rural-wallpaper-mac-ai-implementation.md](docs/superpowers/plans/2026-06-18-rural-wallpaper-mac-ai-implementation.md)

## 当前状态

项目处于实施计划阶段，尚未开始业务代码实现。下一步是选择执行方式，然后按计划进入 Swift/SwiftUI 工程搭建。
