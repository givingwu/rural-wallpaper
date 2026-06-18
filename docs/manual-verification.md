# Manual Verification

## Mock Flow

1. 运行 `swift run RuralWallpaperApp`。
2. 在菜单栏打开 Rural Wallpaper。
3. 点击 `Generate Now`。
4. 打开 `History`。
5. 确认出现一条成功记录，包含 3-5 个英文词、中文释义、例句和评分。
6. 确认生成图片位于 `~/Library/Application Support/RuralWallpaper/Generated/`。

Mock flow 使用 logging desktop setter，不直接替换桌面。

## Real Provider Smoke

1. 打开 `Settings -> Provider`。
2. 填入 `Base URL`、`Model`、`API Key`。
3. 点击 `Test Connection`。
4. 看到连接成功后点击菜单栏 `Generate Now`。
5. 确认桌面壁纸被替换，`History` 出现成功记录。

若 `Test Connection` 失败，设置页应显示错误摘要，并且不保存这次表单配置。若生成阶段 Provider 返回失败，菜单栏状态应显示失败摘要，`History` 应保留失败记录。

## Multi Display

1. 接入多块显示器。
2. 打开 `Settings -> Displays`。
3. 只启用其中一块显示器并保存。
4. 点击 `Generate Now`。
5. 确认只为启用显示器生成记录。
6. 改变显示器连接状态，再次点击 `Generate Now`，确认不会复用已消失显示器任务。

## Desktop Rollback

1. 在 macOS System Settings 中记录当前桌面壁纸。
2. 运行 real provider flow。
3. 如需回滚，在 System Settings 中手动恢复原壁纸。

当前 MVP 未实现自动桌面回滚。

## Keychain And Sensitive Data

1. Provider API Key 只在 Settings 中输入。
2. 确认仓库内不要出现真实 API Key。
3. 检查历史文件：

```bash
rg -n "Bearer |apiKey|sk-" "$HOME/Library/Application Support/RuralWallpaper"
```

4. 若命中真实密钥，停止使用该 Provider Key 并轮换。

自动化测试已覆盖明显敏感字段写入拦截。
