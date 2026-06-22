# Rural Wallpaper Mac AI 设计规格

日期：2026-06-18

## 2026-06-22 方向更新

当前可用性优先版本已收缩为 **Unsplash 原图 + AI 识图学习内容**：

- 真实产品路径不再使用 AI 生成壁纸。
- Unsplash 是默认真实壁纸来源。
- AI Provider 只用于 vision/structured output：从图片中提取 3-5 个英文词、中文释义和例句。
- 桌面壁纸保持干净原图，不叠加英文文案。
- 英文词、释义、例句、来源和失败原因显示在 App 内 History。

下方 2026-06-18 原规格中的 AI 生图、悬挂式排版和视觉评分内容保留为历史设计记录，不再代表当前 MVP 主路径。

## 1. 背景与目标

Rural Wallpaper 是一个面向 macOS 的原生菜单栏应用。它自动生成学习壁纸，并把 3-5 个来自画面语义的英文单词以类似 iOS 26 锁屏时间的方式悬挂在壁纸上。用户看到的是一张干净、高级的桌面壁纸；释义、例句和生成记录留在应用内部。

本项目采用纯 AI Loop + Harness engineering 思路：不是一次生成图片就结束，而是通过候选生成、视觉自评、自动重试和失败回滚形成可观测、可调优的自动闭环。

已确认的 MVP 方向：

- 原生 Swift / SwiftUI macOS 菜单栏应用。
- AI 生成壁纸优先。
- Unsplash 作为可选素材连接器，不作为产品核心壁纸浏览器。
- OpenAI-compatible Provider 可配置：`Base URL`、`Model`、`API Key`、可选 Headers。
- 每块显示器独立生成不同壁纸和不同单词。
- 桌面只显示 3-5 个英文单词。
- 中文释义、例句、评分和失败原因保存在历史详情。

参考依据：

- Apple iOS 26 / macOS Tahoe 26 的新视觉语言强调 Liquid Glass、锁屏时间与照片主体动态适配，以及桌面与系统 UI 融合。
- Unsplash 许可允许免费使用图片，但 API Guidelines 对 attribution、图片 URL、download tracking 和 wallpaper applications 有额外约束。因此 MVP 把 Unsplash 定义为素材连接器，并保留合规记录。

参考链接：

- https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/
- https://unsplash.com/license
- https://unsplash.com/documentation
- https://help.unsplash.com/en/articles/2511245-unsplash-api-guidelines
- https://unsplash.com/terms

## 2. 非目标

MVP 不包含以下内容：

- 用户账号、云同步、社区分享。
- 完整背单词系统、复习曲线或考试词库管理。
- App Store 上架流程。
- 完整 Unsplash/Pexels 浏览器。
- 稳定主体分割深度遮挡。第一版只在主体 mask 可靠时启用深度效果，否则退化为普通前景文字。
- 云端编排服务或远程任务队列。

## 3. 总体架构

采用 **Native Core + Provider Harness**：

- macOS App target 内包含 UI、配置、调度、渲染、历史和桌面设置。
- Provider 通过协议抽象，支持更换不同 OpenAI-compatible 服务。
- Source 通过协议抽象，默认 AI 图片生成，后续可扩展 Unsplash、本地目录、Pexels。
- 每块屏幕拥有独立任务，互不阻塞。

主要模块：

- `MenuBarApp`：菜单栏状态、立即生成、暂停、历史、设置入口。
- `SettingsStore`：保存非敏感配置，例如模型名、Base URL、刷新频率、评分阈值。
- `SecretStore`：使用 macOS Keychain 保存 API Key。
- `ProviderRegistry`：注册和解析 LLM/Image Provider，声明能力。
- `SourceProvider`：素材来源抽象。
- `WallpaperHarness`：全自动闭环编排器。
- `DisplayCoordinator`：发现显示器、监听变化、为每块屏幕派发任务。
- `RenderEngine`：把背景图和词语层合成最终桌面图。
- `HistoryStore`：保存生成记录、词汇详情、评分、失败原因和来源信息。

数据流：

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

## 4. AI Provider 设计

Provider 必须可由用户配置：

- `baseURL`
- `model`
- `apiKey`
- `headers`
- `supportsVision`
- `supportsImageGeneration`
- `supportsStructuredOutput`

API Key 只保存到 Keychain。配置文件或日志中只保存 Keychain 引用，不保存明文密钥。

第一版允许配置一个默认 Provider。内部根据能力调用：

- 图片生成：需要 `supportsImageGeneration`。
- 视觉取词：需要 `supportsVision`。
- 视觉自评：需要 `supportsVision`，最好支持结构化输出。

如果 Provider 能力不足，设置页必须明确提示不可用能力。例如不支持图片生成时，AI Source 不可启用；不支持 vision 时，语义取词和视觉自评不可启用。

所有模型输出要求 JSON schema。解析失败必须进入重试或失败状态，不能把非结构化文本传入渲染流程。

## 5. Source Provider 设计

`SourceProvider` 输出背景图和来源元数据。

MVP 默认来源：

- `AIImageSource`：根据用户主题偏好和屏幕尺寸生成背景图。

可选来源：

- `UnsplashSource`：通过关键词查询和下载素材，保留 photographer、profile、download tracking 等信息。

Unsplash 约束：

- 保留 attribution 元数据。
- 使用 API 返回的图片 URL。
- 按 API 要求触发 download tracking。
- 产品文案避免把应用定位为 Unsplash 壁纸浏览器。
- 允许未来增加开关，在历史详情或设置页展示来源和摄影师信息。

## 6. Wallpaper Harness

每块显示器执行一个独立 `WallpaperJob`。

状态机：

```text
queued
  -> sourcing
  -> extractingWords
  -> planningLayout
  -> rendering
  -> evaluating
  -> applying
  -> done
```

失败状态：

```text
failedProvider
failedParsing
failedRendering
failedEvaluation
failedApply
cancelled
```

任务步骤：

1. 生成主题 brief：结合用户偏好、屏幕信息和随机 seed。
2. 获取背景图：默认 AI 生成；可选 Unsplash 作为素材来源。
3. 语义取词：视觉模型读取图片，输出 3-5 个英文词、中文释义、英文例句、词性、难度和取词理由。
4. 生成布局候选：计算文字位置、字号、权重、颜色、阴影、安全区和深度效果策略。
5. 本地渲染候选：输出多张候选壁纸。
6. 视觉自评：模型按 rubric 打分。
7. 自动重试：低分时先重排版，再重背景。
8. 应用壁纸：评分通过且文件可读后设置到对应显示器。
9. 写入历史：记录结果和失败信息。

默认限制：

- 每个屏幕每轮最多生成 3 张背景。
- 每张背景最多生成 5 个布局候选。
- 达到最大重试后保留原壁纸并记录失败。

## 7. 词语取词规则

单词来自壁纸视觉内容的语义，而不是图片里已有文字。

示例：

- 乡村道路、晨雾、山谷、木屋可以输出 `valley`、`mist`、`cottage`、`dawn`。

输出字段：

- `word`
- `partOfSpeech`
- `zhDefinition`
- `example`
- `difficulty`
- `sourceReason`

桌面只显示 `word`。其它字段只在历史详情中展示。

取词质量要求：

- 词必须与画面语义有关。
- 优先选择常用、可学习、有画面感的词。
- 避免过冷僻、抽象或与画面关系弱的词。
- 每张壁纸随机 3-5 个词，不能固定数量。

## 8. iOS 26 风格悬挂排版

排版目标是让单词像挂在画面空间里，而不是像标签贴在图片上。

算法步骤：

1. 建立屏幕画布：按显示器像素尺寸、scale、色彩空间和安全区生成最终画布。
2. 分析图片：获取主体区域、地平线、建筑边缘、山脊、道路延伸线、低纹理区域、亮度热区和可读性风险。
3. 生成锚点：优先选择靠近主体但不遮挡主体的位置，例如天空空白、山脊上方、建筑边缘或道路延伸线附近。
4. 词组布局：3-5 个词形成轻微错落的松散组，主词更大，辅助词略小。
5. 视觉样式：白色或近白半透明文字，较重字重，轻阴影或玻璃感描边；不使用卡片、标签或释义。
6. 深度效果：主体 mask 可靠时允许局部遮挡文字；不可靠时退化为普通前景文字。
7. 评分：可读性优先，其次是空间贴合感和整体美感。

评分 rubric：

- `readability`
- `sceneFit`
- `depthBelievability`
- `desktopCalmness`
- `wordRelevance`
- `noBadOcclusion`
- `textCorrectness`

低分处理顺序：

1. 换位置。
2. 调字号、颜色、阴影。
3. 重生成背景。

## 9. 多显示器设计

多显示器是 MVP 的一等功能。

`DisplayCoordinator` 通过 `NSScreen.screens` 建立 `DisplayTarget`：

- `id`
- `frame`
- `pixelSize`
- `scale`
- `colorSpace`
- `isMain`
- `friendlyName`

每个 `DisplayTarget` 独立生成：

- 独立背景图。
- 独立词组。
- 独立布局。
- 独立缓存文件。
- 独立历史记录。

屏幕变化处理：

- 新显示器接入：创建新任务。
- 显示器断开：取消对应任务。
- 分辨率或主屏变化：重新计算画布和安全区。

壁纸应用：

- 使用 AppKit 的 `NSWorkspace.shared.setDesktopImageURL(_:for:options:)`。
- 每屏写入独立最终图片。
- 新图通过评分并确认文件可读后才替换旧壁纸。
- 单屏失败不影响其它屏幕。

## 10. UI 与设置

MVP UI 由菜单栏入口和设置窗口组成。

菜单栏：

- 当前状态：`Idle`、`Generating`、`Failed`、`Paused`。
- `Generate Now`：立即为所有启用显示器生成。
- `Pause Auto Update`：暂停自动更新。
- `History`：查看最近记录。
- `Settings`：打开设置窗口。
- `Quit`。

设置窗口：

- AI Provider：`Base URL`、`Model`、`API Key`、自定义 Headers、`Test Connection`。
- Wallpaper Source：AI Generate 默认启用；Unsplash Connector 可选。
- Generation：刷新频率、每屏独立生成、主题偏好、词数范围、难度偏好、最大重试次数、最低评分阈值。默认每天自动更新一次，用户也可以手动触发 `Generate Now`。
- Display：列出当前显示器，允许单独启用/禁用某块屏，并查看最近状态。

历史页：

- 每屏缩略图。
- 英文词。
- 中文释义。
- 英文例句。
- 评分。
- Provider。
- 来源 attribution。
- 失败原因。

## 11. 数据存储

非敏感配置：

- `UserDefaults` 或 App Support JSON。

敏感配置：

- API Key 存 macOS Keychain。

生成文件：

- App Support 目录。
- 按日期和显示器分组。
- 默认每块显示器保留最近 30 次生成记录，后续可做成可配置项，防止无限占用磁盘。

核心数据模型：

- `ProviderConfig`
- `SecretRef`
- `WallpaperJob`
- `GeneratedWallpaper`
- `VocabularyItem`
- `LayoutPlan`
- `EvaluationResult`
- `SourceAttribution`
- `DisplayTarget`

## 12. 错误处理

Provider 连接失败：

- 不启动自动生成。
- 设置页显示错误摘要。

单屏生成失败：

- 只影响该屏。
- 保留旧壁纸。
- 写入失败历史。

JSON 解析失败：

- 按模型输出错误重试。
- 重试耗尽后失败。

评分不达标：

- 先重排版。
- 再重背景。
- 仍失败则保留旧壁纸。

网络失败或限流：

- 指数退避。
- 自动更新暂停到下一周期。
- 手动生成允许用户再次触发。

费用控制：

- 最大重试次数。
- 每日生成次数上限。
- 生成中可取消。

## 13. 测试策略

单元测试：

- Provider 请求构造。
- JSON schema 解析。
- Keychain wrapper。
- 布局候选生成。
- 评分阈值判断。
- Job 状态机。

集成测试：

- 使用 mock provider 跑完整 Harness：source -> words -> layout -> render -> evaluate。

渲染测试：

- 固定输入图和词组。
- 检查输出尺寸、文字边界、安全区、非空像素。
- 做基础快照测试。

多显示器测试：

- 抽象 `DisplayProvider`。
- mock 多屏、屏幕变化、单屏失败。

手工验收：

- 使用真实 Provider 连续生成 3 轮。
- 检查桌面设置。
- 检查历史记录。
- 检查失败回滚。
- 检查 API Key 未落盘。

## 14. 验收标准

MVP 完成时应满足：

- App 可从菜单栏启动和退出。
- 用户可配置 OpenAI-compatible Provider 并测试连接。
- 用户可手动触发为所有启用显示器生成壁纸。
- 每块显示器生成不同图片和不同词组。
- 每张最终壁纸只显示 3-5 个英文词。
- 词语与画面语义相关。
- 低分候选会自动重试。
- 失败不会清空或破坏已有桌面壁纸。
- 历史记录能查看单词释义、例句、评分和失败原因。
- API Key 不出现在配置文件、历史记录和日志中。

## 15. 后续扩展

- 本地目录 Source Provider。
- Pexels Source Provider。
- 更稳定的主体分割和深度遮挡。
- 学习复习系统。
- 多 Provider 分流：一个模型生成图片，另一个模型做视觉评分。
- 成本统计和 token 使用报表。
- App Store 分发适配。
