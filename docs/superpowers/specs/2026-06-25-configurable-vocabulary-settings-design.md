# Configurable Vocabulary and Settings Redesign Design

日期：2026-06-25

## 目标

让用户可以控制一次生成的词表规模，并在预览阶段决定哪些词显示到壁纸上，同时把 Settings 调整为更接近 macOS Tahoe / iOS 26 的 Liquid Glass sidebar 风格。

## 范围

- 新增 `Vocabulary Words` 设置，默认 6，范围 3...24。
- CLI 根据配置生成指定数量的完整词表。
- 预览、历史和词卡保留完整词表。
- 壁纸默认只显示前 6 个词，用户可在预览窗口手动选择显示/隐藏。
- 选择显示词后只重新渲染预览，不重新调用 CLI。
- Settings 改为左侧 sidebar + 右侧分组内容的 Liquid Glass 风格。
- 日志继续保持英文诊断。

## 非目标

- 不在本轮做复杂拖拽排序。
- 不在本轮做按词难度自动推荐显示规则。
- 不把 24 个词默认全部显示到壁纸上。
- 不改变当前 preview-first apply 语义。

## 产品行为

### 词数配置

`AppSettings` 增加 `vocabularyWordCount`：

- 默认值：6。
- 允许范围：3...24。
- Settings 的 Generation 页面通过 stepper 控制。
- 读取旧配置时缺省为 6，保证已有用户配置可迁移。

CLI prompt 使用该值描述需要输出的词数。CLI 返回的 `words.count` 必须等于配置值，否则视为失败并写入英文日志。

### 壁纸显示词选择

生成完成后，`GlassWallpaperPreview` 持有完整词表和当前显示词索引集合：

- 默认选择前 `min(6, words.count)` 个。
- 用户在 Preview 右侧词卡列表中勾选/取消勾选词。
- 勾选数量建议上限为 `wallpaperWordLimit`，默认 6，范围 1...12。
- 如果达到上限，再勾选新词时 UI 给出轻量提示，不隐式替换已有选择。
- 点击 `Update Preview` 后只用现有源图和完整词表重新渲染，保留同一个生成来源，不再跑 Codex。
- `Apply` 应用当前选择对应的预览图。

`Generate Status` 完成态显示完整词数和显示词数，例如：

```text
Done · 01:42 · 24 words · 6 shown
```

### Settings 视觉方向

采用用户确认的 B 方案：

- 左侧 sidebar：`Generation`、`Provider`、`Display`、`Logs`、`About`。
- 右侧为当前 section 的内容，使用半透明 material 分组和紧凑 row。
- 保留原生 SwiftUI 控件：toggle、stepper、slider、segmented picker、button。
- 保持窗口工具性，不做 marketing 风格 hero 或解释性大段文案。
- `Generation` 页面优先展示：
  - `Vocabulary Words`
  - `Wallpaper Words`
  - `Auto Update & Apply`
  - `Refresh`
  - `Layout Candidates`
  - `Minimum Score`
  - `History Per Display`
  - CLI timeout 只读信息：180s

### 其他优化

- README 和中文 README 说明完整词表与壁纸显示词数的区别。
- Preview 右侧词卡列表显示 selected/hidden 状态。
- 日志新增选择变化和重渲染记录：

```text
preview.selection.update selectedWords=6 totalWords=24
render.begin mode=glass selectedWords=6 totalWords=24
```

## 数据流

```text
Generate Preview
  -> 读取 source image
  -> CLI 生成 vocabularyWordCount 个词
  -> 默认选择前 min(wallpaperWordLimit, words.count) 个
  -> 渲染 selected words 到 preview image
  -> Preview 窗口显示完整词表
  -> 用户修改 selected words
  -> 仅重新 render preview image
  -> Apply 当前 preview image
```

## 错误处理

- CLI 返回词数不等于配置值：失败，日志英文说明 expected/actual。
- 用户取消所有显示词：禁用 `Update Preview` 和 `Apply`，提示至少选择一个词。
- 用户超过 `Wallpaper Words` 上限：保持当前选择不变，显示轻量提示。
- 重新渲染失败：保留上一张可用 preview，不应用失败产物。
- 旧配置缺少新增字段：使用默认值并可在下一次保存时写回。

## 测试策略

- `AppSettings` 默认值和 Codable 迁移测试。
- `CLIWordProvider` prompt 和词数校验测试。
- `AppContainer` 生成时按设置请求完整词表，并默认只渲染显示词。
- Preview 选择更新测试：修改选择后只调用 render，不调用 CLI。
- Render 测试：完整词表可超过 6，但 overlay 只渲染传入的 selected words。
- Settings UI 结构测试：sidebar section 和关键控件文案存在。
- README 文档更新检查通过人工 review。
