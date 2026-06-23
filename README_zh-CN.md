# Rural Wallpaper

[English README](README.md)

Rural Wallpaper 是一个原生 macOS 菜单栏英语学习壁纸应用。它会读取当前桌面壁纸，调用本机 Codex 或 Claude Code CLI 从图片内容中识别 3-5 个英文词，再用接近 iOS / Liquid Glass 的低透明度玻璃词牌合成到壁纸上。应用会先展示预览，只有点击 `Apply` 后才会真正替换桌面壁纸。

## 当前能力

- 原生 macOS 菜单栏入口。
- 读取当前桌面壁纸，并兼容 Pap.er 这类工具返回过期文件路径的情况。
- 支持 `Choose Image...` 手动选择本地图片。
- 使用本机 `codex` 或 `claude` CLI 识图并生成英文词。
- 壁纸上只显示英文词和英文词性；中文释义、例句和来源说明显示在预览右侧。
- 支持多显示器预览目标选择。
- 先生成预览，再由用户确认 Apply。
- 单页 grouped Settings：AI Provider、Display、Generation、Logs、About。
- 日志记录 source、CLI、render、preview、apply 等执行步骤。
- 支持通过 Git tag 自动发布 GitHub Release。

## 工作流程

```text
Generate Preview
  -> 解析选中的显示器
  -> 复制当前桌面壁纸或用户选择的图片
  -> 调用本机 CLI 提取英文词
  -> 本地渲染 Liquid Glass 风格词牌
  -> 展示预览和词卡
  -> 用户确认后 Apply
```

生成文件目录：

```bash
~/Library/Application Support/RuralWallpaper/
```

日志路径：

```bash
~/Library/Application Support/RuralWallpaper/rural-wallpaper.log
```

## 环境要求

- macOS 14+
- Swift 6 / Xcode Command Line Tools
- 已登录可用的本机 `codex` 或 `claude` CLI

## 使用方式

源码运行：

```bash
swift run RuralWallpaperApp
```

运行测试：

```bash
swift test
```

打开打包产物：

```bash
open dist/RuralWallpaper-*.app
```

菜单操作：

1. 点击菜单栏里的 Rural Wallpaper 图标。
2. 如果有多个屏幕，先在 `Selected Display` 里选择目标显示器。
3. 点击 `Generate Preview` 或 `Choose Image...`。
4. 在预览窗口检查壁纸和词卡。
5. 点击 `Apply` 后才会替换所选显示器的壁纸。

快捷键：

- `Command-G`：Generate Preview
- `Command-O`：Choose Image
- `Command-,`：Settings
- `Command-L`：Open Logs
- `Command-Q`：Quit

## Settings

Settings 采用单页 grouped 布局：

- `AI Provider`：选择 Codex 或 Claude Code CLI，并测试 Provider。
- `Display`：选择预览目标显示器和启用显示器。
- `Generation`：配置刷新频率、重试次数、布局候选数量、评分阈值和历史保留数量。
- `Logs & Storage`：打开诊断日志。
- `About`：显示当前应用和 Provider 摘要。

## 多显示器行为

`Generate Preview` 会使用当前选中的预览目标显示器。如果这个显示器已经断开，应用会回退到主显示器，再回退到第一块可用显示器。

`Apply` 只会应用到生成该预览时使用的显示器。

## CLI Provider 配置

应用不在界面中保存 OpenAI 或 Anthropic API Key，而是委托给本机已登录的 CLI：

- Codex：`codex`
- Claude Code：`claude`

如果日志中出现 `node: not found`，请检查 `Open Logs` 中的 `cli.path` 是否包含真实 Node 安装路径。

## 打包

Release 构建：

```bash
swift build -c release
```

打包产物会放在 `dist/`：

```text
RuralWallpaper-<timestamp>.app
RuralWallpaper-<timestamp>.zip
```

## GitHub 自动发版

推送 `v*` tag 会触发 GitHub Release：

```bash
git tag v0.1.0
git push origin v0.1.0
```

工作流会运行测试、构建 release app、压缩 zip、按 commit 类型分组生成 release notes，并把 zip 上传到 GitHub Release。

## 排障

- 当前壁纸源文件不存在：应用会在同目录选择最新可读图片作为兜底，并写入日志。
- CLI 报 `node: not found`：安装 Node，或确认 shell manager 的路径已出现在日志中的 `cli.path`。
- 预览效果异常：打开日志，查看最新的 `source`、`words` 和 `render` 阶段。
- 多显示器：生成前先确认菜单里的 `Selected Display`。
