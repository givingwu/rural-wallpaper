# Rural Wallpaper

English | [中文](README_zh-CN.md)

Turn your desktop into a subtle English-learning wallpaper. Rural Wallpaper is a native macOS menu bar app that reads an image, asks your local Codex or Claude Code CLI for useful vocabulary, and lets you preview the finished wallpaper before applying it.

**macOS 14+ · Apple Silicon · Codex or Claude Code CLI**

[Download](https://github.com/givingwu/rural-wallpaper/releases) · [Provider setup](docs/provider-setup.md) · [Manual verification](docs/manual-verification.md)

## What it does

- Uses your selected display's wallpaper or a local image.
- Extracts configurable English vocabulary through your authenticated local CLI; no API key is stored by the app.
- Renders readable Liquid Glass-style word badges with Chinese definitions.
- Lets you select the visible words and preview the result before changing your desktop.
- Supports multiple displays, generation history, detailed logs, and optional automatic updates.

## Get started

1. Download `RuralWallpaper-macOS-arm64.zip` from [Releases](https://github.com/givingwu/rural-wallpaper/releases).
2. Unzip it, move `RuralWallpaper.app` to **Applications**, and open it.
3. Choose **Codex** or **Claude Code** in **Settings**, then make sure that CLI is installed and signed in.
4. Select a display, click **Generate Preview**, choose the words to show, and click **Apply** when satisfied.

The preview build is ad-hoc signed and is **not Apple-notarized**. See [provider setup](docs/provider-setup.md) if macOS cannot find your CLI.

## Everyday flow

`Generate Preview` copies the selected wallpaper or image, asks the configured CLI for words, renders a preview, and never changes your desktop on its own. Use **Apply** to confirm the result. If you enable **Auto Update & Apply**, the same selected-display flow runs on your chosen interval and applies successful previews automatically.

Open **Generate Status** for the current phase, source image, target display, and word counts. **Open Logs** contains a `runID` for tracing one generation from source through rendering and application.

## Settings

- **AI Provider** — choose Codex or Claude Code and test the local CLI.
- **Display** — choose the preview target and enabled displays.
- **Generation** — adjust word counts, visible badges, layout behavior, history, and automatic updates.
- **Logs & Storage** — open diagnostics and generated files.

If the chosen display disappears, the app falls back to the main display and then the first available display. A preview is always applied only to the display it was generated for.

## Build and release

Requires Swift 6 and Xcode Command Line Tools.

```sh
swift test
bash scripts/build-app.sh
```

The signed app and installable ZIP are written to `dist/`. GitHub Actions runs the same tests and packaging on Apple Silicon. Conventional commits on `main` create a Release Please PR; merging it publishes the app ZIP, source ZIP, and SHA-256 checksums. The release build is not notarized.

## Help

- CLI not found: follow [provider setup](docs/provider-setup.md), then inspect **Open Logs** for `cli.path`.
- Wallpaper source missing: the app searches the source folder for the newest readable image and records the fallback in logs.
- Preview is unclear or has the wrong words: regenerate, change visible selections, or adjust Generation settings.
- Need more detail: read [manual verification](docs/manual-verification.md) and inspect the latest `runID` in the log.
