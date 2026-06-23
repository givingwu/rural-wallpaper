# Menu Settings Release Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve display selection, settings layout, generation feedback, README coverage, and tagged release automation.

**Architecture:** Persist the selected preview display in `AppSettings`, resolve the target display inside `AppContainer`, and keep AppKit menu logic thin. Settings remains SwiftUI but switches from a `TabView` to one grouped scroll surface. Release automation lives in `.github/workflows/release.yml` and shell scripts inside the workflow.

**Tech Stack:** Swift 6, SwiftUI, AppKit menu bar app, XCTest, GitHub Actions, shell, `swift build`, `codesign`, `ditto`, `gh release`.

---

### Task 1: Selected Preview Display

**Files:**
- Modify: `Sources/RuralWallpaperCore/Settings/AppSettings.swift`
- Modify: `Sources/RuralWallpaperApp/AppContainer.swift`
- Test: `Tests/RuralWallpaperAppTests/AppContainerTests.swift`

- [ ] Add optional `selectedPreviewDisplayID` to `AppSettings`.
- [ ] Add `selectedPreviewDisplay`, `selectPreviewDisplay(id:)`, `previewDisplay(from:)`, and `openLastPreview()` helpers to `AppContainer`.
- [ ] Make `generateGlassPreview` use the selected preview display with main-display fallback.
- [ ] Write tests for selected display generation and stale selected display fallback.
- [ ] Run `swift test --filter AppContainerTests`.

### Task 2: Menu Workflow and Progress

**Files:**
- Modify: `Sources/RuralWallpaperApp/MenuBar/MenuBarController.swift`
- Modify: `Sources/RuralWallpaperApp/AppContainer.swift`

- [ ] Add published `generationProgressMessage`.
- [ ] Update progress at preview stages and on cancel/failure.
- [ ] Keep a generation task reference in the menu controller.
- [ ] Reorder menu items and add shortcuts.
- [ ] Add `Selected Display` submenu, `Cancel Generation`, and `Open Last Preview`.

### Task 3: Grouped Settings UI

**Files:**
- Modify: `Sources/RuralWallpaperApp/Settings/SettingsView.swift`
- Modify: `Sources/RuralWallpaperApp/Settings/DisplaySettingsView.swift`
- Modify: `Sources/RuralWallpaperApp/Settings/ProviderSettingsView.swift`
- Modify: `Sources/RuralWallpaperApp/Settings/GenerationSettingsView.swift`
- Modify: `Sources/RuralWallpaperApp/Settings/SettingsWindowController.swift`

- [ ] Replace the tab view with one scroll view.
- [ ] Add grouped sections for AI Provider, Display, Generation, Logs, and About.
- [ ] Preserve existing Save and Reload behavior.
- [ ] Add selected preview display picker in Display settings.

### Task 4: README Bilingual Documentation

**Files:**
- Modify: `README.md`

- [ ] Add English section first.
- [ ] Add Chinese section second.
- [ ] Cover current features, usage, CLI setup, multi-display behavior, logs, packaging, release automation, and troubleshooting.

### Task 5: GitHub Release Automation

**Files:**
- Create: `.github/workflows/release.yml`

- [ ] Trigger on `v*` tags.
- [ ] Run tests.
- [ ] Build release app.
- [ ] Package `.app` and `.zip`.
- [ ] Generate grouped release notes from commits since previous tag.
- [ ] Publish GitHub Release with zip artifact.

### Task 6: Verification and Package

**Files:**
- Create: `dist/RuralWallpaper-<timestamp>.app`
- Create: `dist/RuralWallpaper-<timestamp>.zip`

- [ ] Run `swift test --quiet`.
- [ ] Run `swift build -c release`.
- [ ] Sign and verify the `.app`.
- [ ] Zip, unpack, and verify the unpacked `.app`.

