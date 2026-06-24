# Rural Wallpaper

[中文说明](README_zh-CN.md)

Rural Wallpaper is a native macOS menu bar app for English-learning wallpapers. It reads your current desktop wallpaper, asks a local AI CLI such as Codex or Claude Code to identify 3-5 English words from the image, renders subtle iOS / Liquid Glass-style word badges with small Chinese part-of-speech and definition text, and shows a preview before manual changes are applied.

## Features

- Native macOS menu bar workflow.
- Current desktop wallpaper source, with a fallback for stale Pap.er-style file paths.
- Optional local image selection through `Choose Image...`.
- Local AI CLI word extraction through `codex` or `claude`.
- Wallpaper overlay shows English words plus compact Chinese part-of-speech and definition text.
- Multi-display preview target selection.
- Preview-first apply flow: the desktop is changed only after clicking `Apply`.
- Optional `Auto Update & Apply` flow that periodically generates a new preview from the selected display and applies it automatically.
- Grouped Settings window for provider, display, generation, logs, and app information.
- Detailed execution logs for source reads, file writes, CLI, render, preview, and wallpaper apply stages.
- Tag-based GitHub Release automation.

## How It Works

```text
Generate Preview
  -> Resolve selected display
  -> Copy current desktop wallpaper or selected image
  -> Ask local CLI to extract English vocabulary
  -> Render Liquid Glass word badges with Chinese definitions locally
  -> Show preview and word panel
  -> Apply only after confirmation
```

When `Auto Update & Apply` is enabled, the app runs the same selected-display preview generation flow on the configured interval, then applies the generated preview automatically.

Generated files are stored under:

```bash
~/Library/Application Support/RuralWallpaper/
```

Logs are written to:

```bash
~/Library/Application Support/RuralWallpaper/rural-wallpaper.log
```

## Requirements

- macOS 14+
- Swift 6 / Xcode Command Line Tools
- A logged-in local `codex` or `claude` CLI

## Usage

Run from source:

```bash
swift run RuralWallpaperApp
```

Run tests:

```bash
swift test
```

Open a packaged build:

```bash
open dist/RuralWallpaper-*.app
```

Menu workflow:

1. Open the Rural Wallpaper menu bar icon.
2. Pick a target display from `Select Display` if you have multiple screens.
3. Click `Generate Preview` or `Choose Image...`.
4. Review the generated wallpaper and word list.
5. Click `Apply` to set the wallpaper for the selected display.

Menu order:

1. `Select Display`, `Choose Image`, `Generate Preview`
2. `Open Last Preview`, `Open Logs`
3. `Settings`, `Quit`

Shortcuts:

- `Command-G`: Generate Preview
- `Command-O`: Choose Image
- `Command-,`: Settings
- `Command-L`: Open Logs
- `Command-Q`: Quit

## Settings

The Settings window is a single grouped page:

- `AI Provider`: choose Codex or Claude Code CLI and test provider setup.
- `Display`: choose the preview target display and enabled displays.
- `Generation`: configure `Auto Update & Apply`, refresh interval, retry limits, layout candidates, score threshold, and history retention.
- `Logs & Storage`: open diagnostic logs.
- `About`: current app and provider summary.

## Multi-Display Behavior

`Generate Preview` uses the selected preview display. If the selected display disappears, the app falls back to the main display, then to the first available display.

`Apply` applies the preview only to the display that was used to generate it.

`Auto Update & Apply` also uses the selected preview display.

## CLI Provider Setup

The app does not store OpenAI or Anthropic API keys. It delegates image understanding to a local authenticated CLI:

- Codex: `codex`
- Claude Code: `claude`

If the CLI cannot find Node, check `Open Logs` and confirm the logged `cli.path` contains your Node installation path.

If the selected CLI itself is missing, the app shows a direct install reminder such as `未安装 Codex CLI。请先安装并登录 codex，然后重试。`

CLI runs are capped at 180 seconds. The app continuously drains CLI stdout/stderr while it waits, then logs `cli.exit durationSeconds=...` or `cli.timeout ...` so stalled runs do not hang forever.

## Packaging

Build and package locally:

```bash
swift build -c release
scripts/package-macos.sh "$(date +%Y%m%d-%H%M%S)"
```

The packaging script generates `AppIcon.icns`, embeds it in the `.app`, signs the bundle, and writes artifacts to `dist/`:

```text
RuralWallpaper-<timestamp>.app
RuralWallpaper-<timestamp>.zip
```

## GitHub Releases

Pushing a tag matching `v*` triggers the release workflow:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The workflow tests the package, builds a release app, zips it, groups commits since the previous tag, and publishes a GitHub Release with the zip attached.

## Troubleshooting

- Missing current wallpaper file: the app searches the same directory for the newest readable image and logs the fallback.
- CLI exits with `node: not found`: install Node or make sure your shell manager path is visible in the logged CLI path.
- Preview looks wrong: use `Open Logs` and inspect the latest `source`, `file.write`, `words`, and `render` lines.
- Codex takes too long: inspect `cli.exit durationSeconds=...` and `stderrBytes=...` in `Open Logs`. Runs over 180 seconds are stopped and reported as a timeout.
- Wallpaper was not replaced after manual generation: manual generation is preview-first; click `Apply`, or enable `Auto Update & Apply` for automatic replacement.
- Multiple displays: confirm the target in `Select Display` before generating.
