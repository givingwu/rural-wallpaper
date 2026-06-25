# Configurable Vocabulary and Settings Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add configurable vocabulary generation, selectable wallpaper words in Preview, and a Liquid Glass sidebar Settings layout.

**Architecture:** `AppSettings` owns generation counts with Codable defaults for migration. `AppContainer` keeps full generated words and selected display words in `GlassWallpaperPreview`, rendering only selected words and allowing preview re-render without re-running CLI. Settings remains SwiftUI/AppKit but changes to a sidebar shell with focused section views.

**Tech Stack:** Swift 6, SwiftUI, AppKit, CoreGraphics renderer, XCTest, local CLI providers, `swift test`, `swift build -c release`, `scripts/package-macos.sh`.

---

### Task 1: Settings Model and Word Count Validation

**Files:**
- Modify: `Sources/RuralWallpaperCore/Settings/AppSettings.swift`
- Modify: `Sources/RuralWallpaperCore/Provider/CLIWordProvider.swift`
- Modify: `Sources/RuralWallpaperApp/AppContainer.swift`
- Test: `Tests/RuralWallpaperCoreTests/SettingsStoreTests.swift`
- Test: `Tests/RuralWallpaperCoreTests/CLIWordProviderTests.swift`
- Test: `Tests/RuralWallpaperAppTests/AppContainerTests.swift`

- [ ] **Step 1: Write failing settings tests**

Add tests that assert `AppSettings.default.vocabularyWordCount == 6`, `wallpaperWordLimit == 6`, old JSON without those fields decodes with defaults, and out-of-range values clamp to `3...24` and `1...12`.

- [ ] **Step 2: Run tests to verify failure**

Run: `swift test --filter SettingsStoreTests`

Expected: compile/test failure because the fields do not exist.

- [ ] **Step 3: Implement settings fields and migration**

Add `vocabularyWordCount` and `wallpaperWordLimit` to `AppSettings`. Keep existing initializer source-compatible by adding defaulted parameters at the end. Implement custom `Codable` decoding with `decodeIfPresent` and clamping helpers.

- [ ] **Step 4: Write failing CLI count tests**

Add tests that `CLIWordProvider.prompt` includes the requested count and `parseWords` accepts exactly requested count while rejecting mismatches.

- [ ] **Step 5: Implement CLI count support**

Change `ImageFileWordProvider.extractWords(from:)` to `extractWords(from:targetCount:)`. Update `CLIWordProvider` prompt and parser to require the target count. Update test fakes.

- [ ] **Step 6: Update AppContainer validation**

Use `settings.vocabularyWordCount` instead of hard-coded `3...5` for CLI extraction and post-extraction validation. Log `expectedWords` and `actualWords` in English on mismatch.

- [ ] **Step 7: Verify and commit**

Run: `swift test --filter SettingsStoreTests`, `swift test --filter CLIWordProviderTests`, `swift test --filter AppContainerTests`

Commit: `feat(settings): configure vocabulary word count`

### Task 2: Render Only Selected Wallpaper Words

**Files:**
- Modify: `Sources/RuralWallpaperApp/AppContainer.swift`
- Modify: `Sources/RuralWallpaperApp/Status/GenerateStatus.swift`
- Modify: `Sources/RuralWallpaperCore/Render/CoreGraphicsRenderEngine.swift`
- Modify: `Sources/RuralWallpaperCore/Layout/WordLayoutPlanner.swift`
- Modify: `Sources/RuralWallpaperCore/Models/VocabularyItem.swift`
- Test: `Tests/RuralWallpaperAppTests/AppContainerTests.swift`
- Test: `Tests/RuralWallpaperCoreTests/RenderEngineTests.swift`
- Test: `Tests/RuralWallpaperCoreTests/LayoutPlannerTests.swift`

- [ ] **Step 1: Write failing preview selection tests**

Add tests that a preview generated with 24 words stores all 24, selects only the first 6 by default, renders only selected words, and status displays `24 words · 6 shown`.

- [ ] **Step 2: Write failing render/layout tests**

Add tests that renderer accepts selected word counts in `1...12`, and layout/sample helpers can handle more than 5 total words where relevant.

- [ ] **Step 3: Extend preview model**

Add `selectedWordIDs` or selected indexes to `GlassWallpaperPreview`, plus computed `selectedWords`. Prefer stable index-based selection for duplicate words; expose helper methods in `AppContainer`.

- [ ] **Step 4: Update rendering**

Pass `preview.selectedWords` into `renderGlassOverlay`. Relax render validation to `1...12`. Keep the complete word list on the preview object.

- [ ] **Step 5: Add selection update API**

Add `updatePreviewWordSelection(index:isShown:)` and `rerenderActivePreview()` to `AppContainer`. Enforce at least one selected word and `settings.wallpaperWordLimit` max. Log selection and render details in English.

- [ ] **Step 6: Verify and commit**

Run: `swift test --filter AppContainerTests`, `swift test --filter RenderEngineTests`, `swift test --filter LayoutPlannerTests`

Commit: `feat(preview): choose words shown on wallpaper`

### Task 3: Preview UI Word Selection

**Files:**
- Modify: `Sources/RuralWallpaperApp/Preview/WallpaperPreviewView.swift`
- Modify: `Sources/RuralWallpaperApp/Preview/WallpaperPreviewWindowController.swift`
- Test: `Tests/RuralWallpaperAppTests/AppContainerTests.swift`

- [ ] **Step 1: Inspect current preview UI**

Confirm how Apply and Regenerate are wired and avoid changing preview-first semantics.

- [ ] **Step 2: Implement selectable word list**

Change the right panel to show the full word list with selected/hidden state, using checkbox/toggle styling. Add `Update Preview`, `Reset Top N`, and selection count text.

- [ ] **Step 3: Wire preview actions**

Call the `AppContainer` selection update and rerender APIs. Disable update/apply when no words are selected. Show a lightweight message when the user hits the wallpaper word limit.

- [ ] **Step 4: Verify and commit**

Run: `swift test --filter AppContainerTests`

Commit: `feat(preview): add wallpaper word toggles`

### Task 4: Liquid Glass Sidebar Settings

**Files:**
- Modify: `Sources/RuralWallpaperApp/Settings/SettingsView.swift`
- Modify: `Sources/RuralWallpaperApp/Settings/GenerationSettingsView.swift`
- Modify: `Sources/RuralWallpaperApp/Settings/ProviderSettingsView.swift`
- Modify: `Sources/RuralWallpaperApp/Settings/DisplaySettingsView.swift`
- Modify: `Sources/RuralWallpaperApp/Settings/SettingsWindowController.swift`
- Test: add targeted view/model tests if feasible, otherwise rely on `swift build` and manual visual checks.

- [ ] **Step 1: Add settings section enum**

Create a private sidebar enum with `Generation`, `Provider`, `Display`, `Logs`, and `About` entries.

- [ ] **Step 2: Rebuild Settings shell**

Use a horizontal layout: translucent sidebar on the left, selected section on the right. Keep native controls and Save/Reload footer.

- [ ] **Step 3: Update Generation controls**

Add steppers for `Vocabulary Words` (`3...24`) and `Wallpaper Words` (`1...12`). Show read-only `CLI Timeout: 180s`. Keep existing refresh/layout/history controls.

- [ ] **Step 4: Polish material and spacing**

Use restrained `.regularMaterial` / `.ultraThinMaterial`, 12-16 px grouped rows, 8-14 px radii, and avoid nested cards.

- [ ] **Step 5: Verify and commit**

Run: `swift build` and targeted tests changed by model work.

Commit: `feat(settings): redesign settings sidebar`

### Task 5: Documentation, Package, and Final Verification

**Files:**
- Modify: `README.md`
- Modify: `README_zh-CN.md`
- Modify: `docs/manual-verification.md`
- Create: `dist/RuralWallpaper-<timestamp>.app`
- Create: `dist/RuralWallpaper-<timestamp>.zip`

- [ ] **Step 1: Update docs**

Document generated words vs wallpaper words, preview toggles, Settings controls, and no-CLI rerender behavior.

- [ ] **Step 2: Run full verification**

Run:

```bash
swift test
swift build -c release
scripts/package-macos.sh "$(date +%Y%m%d-%H%M%S)"
```

Expected: all tests pass, release build succeeds, package script signs and verifies `.app`.

- [ ] **Step 3: Commit docs if separate**

Commit: `docs: document configurable vocabulary workflow`

- [ ] **Step 4: Final status**

Report commits, dist paths, and verification commands with results.
