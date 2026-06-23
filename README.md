# Rural Wallpaper

[中文说明](README_zh-CN.md)

Rural Wallpaper is a native macOS menu bar app for English-learning wallpapers. It reads your current desktop wallpaper, asks a local AI CLI such as Codex or Claude Code to identify 3-5 English words from the image, renders subtle iOS / Liquid Glass-style word badges onto the wallpaper, and shows a preview before anything is applied.

## Features

- Native macOS menu bar workflow.
- Current desktop wallpaper source, with a fallback for stale Pap.er-style file paths.
- Optional local image selection through `Choose Image...`.
- Local AI CLI word extraction through `codex` or `claude`.
- English-only wallpaper overlay; Chinese definitions and examples stay in the preview panel.
- Multi-display preview target selection.
- Preview-first apply flow: the desktop is changed only after clicking `Apply`.
- Grouped Settings window for provider, display, generation, logs, and app information.
- Execution logs for source, CLI, render, preview, and apply stages.
- Tag-based GitHub Release automation.

## How It Works

```text
Generate Preview
  -> Resolve selected display
  -> Copy current desktop wallpaper or selected image
  -> Ask local CLI to extract English vocabulary
  -> Render Liquid Glass word badges locally
  -> Show preview and word panel
  -> Apply only after confirmation
```

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
2. Pick a target display from `Selected Display` if you have multiple screens.
3. Click `Generate Preview` or `Choose Image...`.
4. Review the generated wallpaper and word list.
5. Click `Apply` to set the wallpaper for the selected display.

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
- `Generation`: configure refresh interval, retry limits, layout candidates, score threshold, and history retention.
- `Logs & Storage`: open diagnostic logs.
- `About`: current app and provider summary.

## Multi-Display Behavior

`Generate Preview` uses the selected preview display. If the selected display disappears, the app falls back to the main display, then to the first available display.

`Apply` applies the preview only to the display that was used to generate it.

## CLI Provider Setup

The app does not store OpenAI or Anthropic API keys. It delegates image understanding to a local authenticated CLI:

- Codex: `codex`
- Claude Code: `claude`

If the CLI cannot find Node, check `Open Logs` and confirm the logged `cli.path` contains your Node installation path.

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
- Preview looks wrong: use `Open Logs` and inspect the latest `source`, `words`, and `render` lines.
- Multiple displays: confirm the target in `Selected Display` before generating.
