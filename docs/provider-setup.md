# CLI Provider Setup

当前主流程使用本机 AI CLI，不在 App 里填写 Base URL、Model 或 API Key。

## 支持的 CLI

- `codex`
- `claude`

App 会通过 `Process` 调用本机命令：

- Codex：`codex exec --skip-git-repo-check --ephemeral --sandbox read-only --image <path> -- <prompt>`
- Claude：`claude --print --output-format text <prompt>`

## 设置入口

1. 启动 App。
2. 点击菜单栏 Rural Wallpaper 图标。
3. 打开 `Settings -> Provider`。
4. 在 `AI CLI` 中选择 `Codex` 或 `Claude`。
5. 点击 `Save`。

## 输出要求

CLI 必须返回 JSON，格式如下：

```json
{
  "words": [
    {
      "word": "tranquil",
      "partOfSpeech": "adjective",
      "zhDefinition": "宁静的",
      "example": "The lake feels tranquil at sunrise.",
      "difficulty": 3,
      "sourceReason": "The scene has calm water and soft light."
    }
  ]
}
```

如果 CLI 输出 Markdown code fence，App 会尝试提取其中的 JSON。非 JSON 输出会中断生成，并在 App 中显示错误。

## 注意

- App 不保存 AI API Key。
- 真实鉴权由 `codex` 或 `claude` CLI 自己管理。
- GUI App 从 Finder 启动时不会读取你的 shell rc 文件。App 会自动补充常见 CLI / Node 路径，包括 `~/.nvm/versions/node/*/bin`、`~/.volta/bin`、`~/.asdf/shims`、`~/.mise/shims`、`~/.local/share/pnpm`、`~/.local/bin`、`/opt/homebrew/bin` 和 `/usr/local/bin`。
- 如果日志出现 `exec: node: not found`，优先检查 `Open Logs` 中的 `cli.path` 是否包含实际 `node` 所在目录。
