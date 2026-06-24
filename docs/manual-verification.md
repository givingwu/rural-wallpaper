# Manual Verification

## Glass Preview Flow

1. 确认当前 macOS 桌面已经设置了一张本地壁纸。
2. 确认 `codex` 或 `claude` CLI 已登录并可在终端运行。
3. 运行 `swift run RuralWallpaperApp`，或打开打包后的 `.app`。
4. 在菜单栏打开 Rural Wallpaper。
5. 打开 `Settings -> Provider`，选择 `Codex` 或 `Claude`，点击 `Save`。
6. 点击 `Generate Preview`。
7. 确认出现 Preview 窗口，左侧壁纸显示分散的低透明度玻璃词牌，英文词从左到右可正常阅读且不镜像，每个词牌都有中文词性和中文释义小字；右侧显示 3-5 个英文词、中文释义和例句。
8. 点击 `Cancel`，确认当前桌面壁纸没有被替换。
9. 再次点击 `Generate Preview`，然后点击 `Apply`。
10. 确认当前桌面壁纸被替换为预览图。
11. 点击菜单栏 `Open Logs`，确认打开日志文件并能看到 `preview.begin`、`preview.directory.create.*`、`source.begin`、`source.image.read.done`、`file.write.*`、`words.begin`、`render.begin`、`apply.wallpaper.set.*`、`preview.done`、`apply.done` 等记录。

生成文件位于：

```bash
~/Library/Application Support/RuralWallpaper/Previews/
~/Library/Application Support/RuralWallpaper/CurrentDesktop/
~/Library/Application Support/RuralWallpaper/rural-wallpaper.log
```

## CLI Failure

1. 临时选择一个未登录、不可用或未安装的 CLI。
2. 点击 `Generate Preview`。
3. 如果 CLI 未安装，确认错误文案明确提示 `未安装 Codex CLI` 或 `未安装 Claude Code CLI`。
4. 确认菜单栏状态显示失败摘要，Preview 不会自动 Apply。

## Auto Update & Apply

1. 打开 `Settings -> Generation`。
2. 开启 `Auto Update & Apply`，把刷新间隔设为需要验证的值并保存。
3. 重新启动 App，或等待下一次自动检查。
4. 确认日志出现 `auto_update.begin`、`preview.begin`、`apply.wallpaper.set.done`、`auto_update.done`。
5. 确认所选显示器壁纸被自动替换为生成后的预览图。

## Missing Desktop Source File

Pap.er 等壁纸工具可能会让 macOS 记住一个已经被删除的源图片路径。此时日志会出现：

```text
source.begin provider=current-desktop
source.done ... prompt=Current desktop wallpaper fallback: 2336514259321618432.heic
```

处理方式：

1. 点击 `Generate Preview`。
2. 如果原桌面源文件已被删除，但同目录还有其他可读图片，确认 Preview 窗口正常出现。
3. 打开 `Open Logs`，确认 `source.done` 行包含 `Current desktop wallpaper fallback: <filename>`。
4. 点击 `Apply` 后再替换桌面。
5. 如果同目录没有可用图片，再点击菜单栏 `Choose Image...` 选择一张实际存在的本地图片。

## Multi Display

当前预览和 `Auto Update & Apply` 流程使用菜单里的 `Select Display`。如果所选显示器消失，会回退到主显示器，再回退到第一块可用显示器。

## Desktop Rollback

当前 MVP 未实现自动回滚。测试前如需保留原壁纸，请在 macOS System Settings 中记住原图或手工备份。
