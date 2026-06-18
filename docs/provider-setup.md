# Provider Setup

Rural Wallpaper 使用 OpenAI-compatible Provider。设置入口在菜单栏 `Settings -> Provider`。

## 字段

- `Base URL`：Provider 的 OpenAI-compatible API 根地址，例如 `https://api.openai.com/v1` 或你的代理服务地址。
- `Model`：同时支持 vision、image generation、structured output 的模型名称。不同 Provider 的可用模型不同，请以你的 Provider 控制台为准。
- `API Key`：只写入 macOS Keychain，不写入 `UserDefaults`、历史 JSON 或测试 fixture。
- `Headers`：可选的非敏感附加 header，每行 `Name: Value`。不要把 Authorization、API Key、Token 或 Secret 放在这里。

## Test Connection

`Test Connection` 会使用当前表单里的 API Key 临时向 `/chat/completions` 发送一个最小 JSON 探测请求：

- 成功：API Key 写入 Keychain，非敏感配置写入 `UserDefaults`，设置页显示连接成功，并把生成模式切到真实 Provider。
- 失败：设置页显示错误摘要，不保存这次表单配置，并继续使用本地 mock preview flow。

## 能力要求

用于完整生成时，Provider 需要支持：

- Vision：从图片中提取 3-5 个英文词并分析安全排版区域。
- Image generation：生成无文字桌面壁纸原图。
- Structured output：返回 JSON，便于解析词汇、画面分析和评分。

## 安全检查

- 不要提交真实 API Key。
- 不要把 API Key 写入 `Headers`。
- 生成历史写入前会扫描明显的 `Bearer `、`apiKey`、`sk-...` 形态并拒绝写入。
- 自动测试全部使用 mock，不会访问真实 Provider。
