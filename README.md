# Rural Wallpaper

[中文说明](README_zh-CN.md)

Rural Wallpaper is a native macOS menu bar app for English-learning wallpapers. It reads your current desktop wallpaper, asks a local AI CLI such as Codex or Claude Code to identify configurable English words from the image, renders subtle iOS / Liquid Glass-style word badges with small Chinese part-of-speech and definition text, and shows a preview before manual changes are applied.

## Features

- Native macOS menu bar workflow.
- Current desktop wallpaper source, with a fallback for stale Pap.er-style file paths.
- Optional local image selection through `Choose Image...`.
- Local AI CLI word extraction through `codex` or `claude`, defaulting to 6 generated words and supporting up to 24 candidates.
- Wallpaper overlay shows English words plus compact Chinese part-of-speech and definition text.
- Adaptive badge contrast keeps generated text readable on bright or white wallpaper areas.
- Preview word selection: choose which generated words are visible on the wallpaper, up to 12 visible badges.
- Multi-display preview target selection.
- Menu `Generate Status` area with live phase, elapsed time, source image, working image, target display, generated/visible word counts, and last preview path.
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
  -> Render selected Liquid Glass word badges with Chinese definitions locally
  -> Show preview and selectable word panel
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
2. Check `Generate Status` for the current phase, elapsed time, source image, and target display.
3. Pick a target display from `Select Display` if you have multiple screens.
4. Click `Generate Preview` or `Choose Image...`.
5. Review the generated wallpaper and choose which words are visible.
6. Click `Apply` to set the wallpaper for the selected display.

Menu order:

1. `Generate Status`
2. `Select Display`, `Choose Image`, `Generate Preview`
3. `Open Last Preview`, `Open Logs`
4. `Settings`, `Quit`

Shortcuts:

- `Command-G`: Generate Preview
- `Command-O`: Choose Image
- `Command-,`: Settings
- `Command-L`: Open Logs
- `Command-Q`: Quit

## Settings

The Settings window uses a Liquid Glass-style sidebar:

- `AI Provider`: choose Codex or Claude Code CLI and test provider setup.
- `Display`: choose the preview target display and enabled displays.
- `Generation`: configure generated word count, visible word limit, `Auto Update & Apply`, refresh interval, retry limits, layout candidates, score threshold, and history retention.
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

During generation, `Generate Status` shows the current phase such as `Extracting words`, elapsed time, and the 180-second cap. After a run finishes, it shows whether the source was a screen wallpaper or chosen image, the exact source filename, the copied working image filename, the target display resolution, the preview filename, and generated/visible word counts. Logs use English diagnostics and include a `runID=...` value on the detailed source, file write, CLI, render, preview, selection render, and apply lines for tracing one run end to end.

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
- Text looks unclear on bright backgrounds: generated badges automatically switch to darker text and outlines in bright regions.
- Too many or too few words: change `Settings` -> `Generation` -> `Generated Words` and `Visible on Wallpaper`.
- Codex takes too long: inspect `cli.exit durationSeconds=...` and `stderrBytes=...` in `Open Logs`. Runs over 180 seconds are stopped and reported as a timeout.
- Cannot tell which image was used: open the menu and check `Generate Status`, or search the latest matching `runID=...` in `Open Logs`.
- Wallpaper was not replaced after manual generation: manual generation is preview-first; click `Apply`, or enable `Auto Update & Apply` for automatic replacement.
- Multiple displays: confirm the target in `Select Display` before generating.
