# Current Desktop CLI Glass Preview 设计规格

日期：2026-06-22

## 目标

把 Rural Wallpaper 收缩成一个本机可用的最小闭环：

- 不再从 Unsplash 获取壁纸。
- 不再在 App 内配置 LLM Provider API Key。
- 直接读取当前 macOS 桌面壁纸。
- 通过本机 `codex` 或 `claude` CLI 生成 3-5 个英文学习词。
- 本地把 iOS / Liquid Glass 风格文案合成到当前壁纸上。
- 先展示预览，用户点 `Apply` 后才替换现有桌面壁纸。

## 非目标

- 不做云端账号、素材浏览器、自动定时更新。
- 不做 AI 生图。
- 不做 Unsplash 主流程。
- 不在第一版做复杂主体分割或深度遮挡。
- 不自动覆盖桌面，必须经过用户确认。

## 用户流程

```text
菜单栏
  -> Generate Preview
  -> 读取当前主屏桌面壁纸
  -> 调用 CLI 文案 Provider
  -> 解析词卡 JSON
  -> 本地合成玻璃风预览图
  -> 打开 Preview 窗口
  -> Apply
  -> 设置为当前桌面壁纸
```

## 组件设计

### CurrentDesktopSource

读取当前显示器现有桌面壁纸 URL，并复制到 App Support 的工作目录中。复制后的文件作为后续渲染输入，避免直接改动系统当前文件。

### CLIWordProvider

抽象为一个本地进程 Provider：

- 优先使用用户选择的命令：`codex` 或 `claude`。
- 输入包含图片路径、期望 JSON schema 和输出语言要求。
- 输出必须是 JSON，包含 `words` 数组。
- 解析失败时给出可读错误，不进入渲染。

第一版允许 CLI 不真正理解图片时退化为基于文件名/通用自然场景的词卡，但接口按真实视觉 Provider 设计。

### GlassWallpaperRenderer

基于现有 CoreGraphics 渲染能力，把玻璃文案层叠到当前桌面图上：

- 半透明圆角玻璃面板。
- 轻微描边和阴影。
- 显示 3-5 个英文词，主词更突出。
- 中文释义和例句可显示在面板内，便于确认学习内容。
- 自动选择顶部或底部的低风险区域，避免居中遮挡主体。

### Preview Window

新增预览窗口，显示生成后的图片和词卡信息，提供：

- `Apply`：把预览图设置为当前桌面。
- `Regenerate`：重新生成文案和预览。
- `Cancel`：关闭窗口，不修改桌面。

## 错误处理

- 未找到当前桌面壁纸：提示用户选择已有桌面图片或检查系统桌面设置。
- CLI 不存在：提示安装或切换命令。
- CLI 输出非 JSON：保留原始错误摘要并停止。
- 渲染失败：不应用壁纸，保留当前桌面。
- Apply 失败：显示系统错误，不删除预览文件。

## 测试策略

- 单元测试覆盖当前桌面源 URL 解析。
- 单元测试覆盖 CLI JSON 解析和非 JSON 错误。
- 单元测试覆盖玻璃渲染输出文件存在且尺寸匹配。
- App 层用 mock Provider 测试 Preview 状态流，不调用真实 CLI。
