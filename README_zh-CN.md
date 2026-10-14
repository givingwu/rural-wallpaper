# Rural Wallpaper

[English](README.md) | 中文

把桌面变成轻量的英语学习壁纸。Rural Wallpaper 是原生 macOS 菜单栏应用：它读取图片，通过本机已登录的 Codex 或 Claude Code CLI 提取实用词汇，生成预览后再由你决定是否应用。

**macOS 14+ · Apple Silicon · Codex 或 Claude Code CLI**

[下载](https://github.com/givingwu/rural-wallpaper/releases) · [Provider 配置](docs/provider-setup.md) · [人工验证说明](docs/manual-verification.md)

## 能做什么

- 使用指定显示器的当前壁纸，或选择本地图片。
- 调用本机已登录的 CLI 提取可配置数量的英文词；应用不保存 API Key。
- 生成带中文词性和释义的 Liquid Glass 风格词牌，并自动保持可读性。
- 在替换桌面前选择展示的词并预览结果。
- 支持多显示器、历史记录、详细日志和可选的自动更新。

## 快速开始

1. 从 [Releases](https://github.com/givingwu/rural-wallpaper/releases) 下载 `RuralWallpaper-macOS-arm64.zip`。
2. 解压，将 `RuralWallpaper.app` 移到**应用程序**，然后打开。
3. 在**设置**中选择 Codex 或 Claude Code，并确保对应 CLI 已安装、已登录。
4. 选择显示器，点击 **Generate Preview**；检查预览并选择要显示的词，满意后点击 **Apply**。

当前预览版为 ad-hoc 签名，**尚未经过 Apple notarization**。若 macOS 找不到 CLI，请参考 [Provider 配置](docs/provider-setup.md)。

## 日常流程

`Generate Preview` 会复制选中的壁纸或图片，调用配置好的 CLI 生成词汇，再渲染预览；在你点击 **Apply** 前不会修改桌面。启用 **Auto Update & Apply** 后，应用会按设定间隔对所选显示器执行同一流程，并自动应用成功的预览。

在 **Generate Status** 可查看当前阶段、来源图片、目标显示器和词数；**Open Logs** 会记录每次生成的 `runID`，可用于串联排查来源、渲染和应用过程。

## 设置

- **AI Provider**：选择 Codex 或 Claude Code，并测试本机 CLI。
- **Display**：选择预览目标和启用的显示器。
- **Generation**：调整生成词数、可见词牌、布局、历史记录和自动更新。
- **Logs & Storage**：打开诊断日志与生成文件。

若选中的显示器断开，应用会回退到主显示器，再回退到第一块可用显示器。预览只会应用到生成它的那块显示器。

## 构建与发版

需要 Swift 6 和 Xcode Command Line Tools。

```sh
swift test
bash scripts/build-app.sh
```

已签名的 app 与安装包会写入 `dist/`。GitHub Actions 会在 Apple Silicon 上执行同样的测试和打包。提交到 `main` 的 Conventional Commit 会生成 Release Please PR；合并该 PR 后，将发布 app ZIP、源码 ZIP 与 SHA-256 校验文件。发布包尚未 notarize。

## 帮助

- 找不到 CLI：按 [Provider 配置](docs/provider-setup.md) 检查，并在 **Open Logs** 查看 `cli.path`。
- 找不到壁纸源文件：应用会在同目录使用最新的可读图片，并在日志记录回退行为。
- 预览不清晰或词不合适：重新生成、调整可见词，或修改 Generation 设置。
- 需要完整排障信息：查看 [人工验证说明](docs/manual-verification.md)，并在日志中搜索最近的 `runID`。
