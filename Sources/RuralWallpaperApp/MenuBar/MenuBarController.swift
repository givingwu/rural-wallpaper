import AppKit
import RuralWallpaperCore

@MainActor
final class MenuBarController: NSObject {
    private let container: AppContainer
    private let statusItem: NSStatusItem
    private let settingsWindowController: SettingsWindowController
    private let historyWindowController: HistoryWindowController
    private var state = MenuBarState()

    init(container: AppContainer) {
        self.container = container
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.settingsWindowController = SettingsWindowController(container: container)
        self.historyWindowController = HistoryWindowController(container: container)
        super.init()
    }

    func install() {
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "photo.on.rectangle.angled",
                accessibilityDescription: "Rural Wallpaper"
            )
            button.image?.isTemplate = true
            button.title = ""
        }

        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let status = NSMenuItem(title: state.statusTitle, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let generate = NSMenuItem(
            title: "Generate Now",
            action: #selector(generateNow),
            keyEquivalent: "g"
        )
        generate.target = self
        generate.isEnabled = !state.isGenerating
        menu.addItem(generate)

        let pause = NSMenuItem(
            title: "Pause Auto Update",
            action: #selector(togglePause),
            keyEquivalent: "p"
        )
        pause.target = self
        pause.state = state.isPaused ? .on : .off
        menu.addItem(pause)
        menu.addItem(.separator())

        let history = NSMenuItem(title: "History", action: #selector(showHistory), keyEquivalent: "h")
        history.target = self
        menu.addItem(history)

        let settings = NSMenuItem(title: "Settings", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func generateNow() {
        guard state.beginManualGeneration() else {
            rebuildMenu()
            return
        }

        rebuildMenu()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            state.finishWithFailure("Generation flow is not connected yet.")
            rebuildMenu()
        }
    }

    @objc private func togglePause() {
        state.setPaused(!state.isPaused)
        rebuildMenu()
    }

    @objc private func showSettings() {
        settingsWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showHistory() {
        historyWindowController.reload()
        historyWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
