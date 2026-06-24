# Rural Wallpaper

[English README](README.md)

Rural Wallpaper 是一个原生 macOS 菜单栏英语学习壁纸应用。它会读取当前桌面壁纸，调用本机 Codex 或 Claude Code CLI 从图片内容中识别 3-5 个英文词，再用接近 iOS / Liquid Glass 的低透明度玻璃词牌合成到壁纸上。词牌会显示英文词，并用小字显示中文词性和释义。手动生成时应用会先展示预览，只有点击 `Apply` 后才会真正替换桌面壁纸。

## 当前能力

- 原生 macOS 菜单栏入口。
- 读取当前桌面壁纸，并兼容 Pap.er 这类工具返回过期文件路径的情况。
- 支持 `Choose Image...` 手动选择本地图片。
- 使用本机 `codex` 或 `claude` CLI 识图并生成英文词。
- 壁纸词牌显示英文词、中文词性和中文释义；例句和来源说明显示在预览右侧。
- 支持多显示器预览目标选择。
- 菜单顶部 `Generate Status` 展示当前阶段、耗时、图片来源、目标显示器和最近预览路径。
- 先生成预览，再由用户确认 Apply。
- 支持 `Auto Update & Apply`：按刷新间隔自动生成所选显示器的预览并自动应用。
- 单页 grouped Settings：AI Provider、Display、Generation、Logs、About。
- 日志记录 source 读取、文件写入、CLI、render、preview、apply 等细节步骤。
- 支持通过 Git tag 自动发布 GitHub Release。

## 工作流程

```text
Generate Preview
  -> 解析选中的显示器
  -> 复制当前桌面壁纸或用户选择的图片
  -> 调用本机 CLI 提取英文词
  -> 本地渲染带中文释义的 Liquid Glass 风格词牌
  -> 展示预览和词卡
  -> 用户确认后 Apply
```

如果开启 `Auto Update & Apply`，应用会按配置间隔执行同一套所选显示器预览生成流程，并在生成成功后自动 Apply。

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
2. 先看 `Generate Status`，确认当前阶段、耗时、图片来源和目标显示器。
3. 如果有多个屏幕，先在 `Select Display` 里选择目标显示器。
4. 点击 `Generate Preview` 或 `Choose Image...`。
5. 在预览窗口检查壁纸和词卡。
6. 点击 `Apply` 后才会替换所选显示器的壁纸。

菜单顺序：

1. `Generate Status`
2. `Select Display`、`Choose Image`、`Generate Preview`
3. `Open Last Preview`、`Open Logs`
4. `Settings`、`Quit`

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
- `Generation`：配置 `Auto Update & Apply`、刷新频率、重试次数、布局候选数量、评分阈值和历史保留数量。
- `Logs & Storage`：打开诊断日志。
- `About`：显示当前应用和 Provider 摘要。

## 多显示器行为

`Generate Preview` 会使用当前选中的预览目标显示器。如果这个显示器已经断开，应用会回退到主显示器，再回退到第一块可用显示器。

`Apply` 只会应用到生成该预览时使用的显示器。

`Auto Update & Apply` 同样使用当前选中的预览目标显示器。

## CLI Provider 配置

应用不在界面中保存 OpenAI 或 Anthropic API Key，而是委托给本机已登录的 CLI：

- Codex：`codex`
- Claude Code：`claude`

如果日志中出现 `node: not found`，请检查 `Open Logs` 中的 `cli.path` 是否包含真实 Node 安装路径。

如果所选 CLI 本身未安装，应用会直接提示，例如：`未安装 Codex CLI。请先安装并登录 codex，然后重试。`

CLI 单次执行默认最多等待 180 秒。应用会在等待期间持续读取 CLI 的 stdout/stderr，避免 Codex 进度输出写满 pipe 后卡死；日志会记录 `cli.exit durationSeconds=...` 或 `cli.timeout ...`。

生成过程中，`Generate Status` 会显示 `Extracting words` 等当前阶段、已耗时和 180 秒上限。生成完成后，它会继续显示来源类型（屏幕墙纸或用户选择图片）、来源文件名、目标显示器分辨率、预览文件名和词数。日志中的 source、file.write、CLI、render、preview、apply 细节行都会带 `runID=...`，方便追踪一次完整生成。

## 打包

本地构建和打包：

```bash
swift build -c release
scripts/package-macos.sh "$(date +%Y%m%d-%H%M%S)"
```

打包脚本会生成 `AppIcon.icns`，写入 `.app`，完成签名，并把产物放在 `dist/`：

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
- CLI 未安装：安装并登录所选 CLI，例如 `codex` 或 `claude`。
- Codex 执行太久：打开日志查看 `cli.exit durationSeconds=...` 和 `stderrBytes=...`；超过 180 秒会自动停止本次生成并提示超时。
- 预览效果异常：打开日志，查看最新的 `source`、`file.write`、`words` 和 `render` 阶段。
- 手动生成后壁纸没有替换：手动流程是预览优先，需要点击 `Apply`；如果要自动替换，请开启 `Auto Update & Apply`。
- 不确定用了哪张图片生成：先看菜单里的 `Generate Status`，或在日志中搜索最近的 `runID=...`。
- 多显示器：生成前先确认菜单里的 `Select Display`。
