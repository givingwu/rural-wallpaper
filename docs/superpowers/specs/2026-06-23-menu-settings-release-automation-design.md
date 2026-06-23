# Menu, Settings, and Release Automation Design

## Goal

Improve the macOS menu bar workflow so multi-display users can intentionally choose a target display, settings feel like one system-style grouped surface, generation communicates progress, documentation is bilingual, and tagged builds publish GitHub Releases automatically.

## Scope

- Add a persistent selected preview display used by `Generate Preview`, `Choose Image...`, preview metadata, and apply.
- Rework Settings from tabbed pages into one grouped scroll view with sections for AI Provider, Display, Generation, Logs, and About.
- Reorder menu items around the common workflow and add keyboard shortcuts.
- Expose generation progress in the menu and allow cancelling an in-flight generation task.
- Update `README.md` with English and Chinese sections covering current capabilities.
- Add a tag-triggered GitHub Actions release workflow that builds, tests, packages, groups commits, and publishes a Release.

## Product Behavior

### Display Selection

The app keeps a selected preview display ID in settings. On startup and display refresh, if that ID still exists, preview generation targets it. If not, the app falls back to the main display, then the first available display. The menu exposes a `Selected Display` submenu with checkmarks, and Settings shows the same selected display plus enabled displays for future all-display workflows.

### Menu Workflow

The menu should prioritize the manual preview loop:

1. Status / progress row
2. `Generate Preview`
3. `Choose Image...`
4. `Cancel Generation` while running
5. `Selected Display`
6. `Open Last Preview`
7. `Settings...`
8. `Open Logs`
9. `Quit`

Shortcuts:

- `Command-G`: Generate Preview
- `Command-O`: Choose Image
- `Command-,`: Settings
- `Command-L`: Open Logs
- `Command-Q`: Quit

### Settings

Settings becomes one scrollable grouped page. It uses native SwiftUI controls and subtle grouped cards rather than tabs. Each group is independently understandable and keeps existing save/reload behavior. Provider connection testing remains available.

### Generation Progress

Generation progress is stored in `AppContainer` and updated at major stages:

- Preparing display
- Reading wallpaper
- Extracting words
- Rendering preview
- Ready
- Failed / Cancelled

The menu shows the current step. Cancellation cancels the task from the menu controller; the container reports a cancelled status instead of leaving stale progress.

### Release Automation

On `v*` tags, GitHub Actions runs tests, builds a release binary, creates a `.app` bundle, ad-hoc signs it, zips it, groups commits since the previous tag by Conventional Commit prefix, and publishes a GitHub Release with the zip attached.

## Testing

- AppContainer tests verify selected display generation and fallback behavior.
- Menu-progress logic is covered through AppContainer state tests where possible.
- Existing preview/apply tests continue to verify no wallpaper is applied before confirmation.
- Workflow syntax is kept shell-only and does not require third-party actions beyond official checkout/setup primitives.

