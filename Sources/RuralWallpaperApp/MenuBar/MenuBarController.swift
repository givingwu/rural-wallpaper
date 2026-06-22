import AppKit
import RuralWallpaperCore
import UniformTypeIdentifiers

@MainActor
final class MenuBarController: NSObject {
    private let container: AppContainer
    private let statusItem: NSStatusItem
    private let settingsWindowController: SettingsWindowController
    private let previewWindowController: WallpaperPreviewWindowController
    private var state = MenuBarState()

    init(container: AppContainer) {
        self.container = container
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.settingsWindowController = SettingsWindowController(container: container)
        self.previewWindowController = WallpaperPreviewWindowController(container: container)
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
            title: "Generate Preview",
            action: #selector(generatePreview),
            keyEquivalent: "g"
        )
        generate.target = self
        generate.isEnabled = !state.isGenerating
        menu.addItem(generate)

        let choose = NSMenuItem(
            title: "Choose Image...",
            action: #selector(chooseImagePreview),
            keyEquivalent: "o"
        )
        choose.target = self
        choose.isEnabled = !state.isGenerating
        menu.addItem(choose)
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let logs = NSMenuItem(title: "Open Logs", action: #selector(openLogs), keyEquivalent: "l")
        logs.target = self
        menu.addItem(logs)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func generatePreview() {
        runPreviewGeneration {
            try await self.container.generateGlassPreview()
        }
    }

    @objc private func chooseImagePreview() {
        guard !state.isGenerating else {
            rebuildMenu()
            return
        }

        let panel = NSOpenPanel()
        panel.title = "Choose Wallpaper Image"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        runPreviewGeneration {
            try await self.container.generateGlassPreview(from: url)
        }
    }

    private func runPreviewGeneration(
        _ operation: @escaping @MainActor () async throws -> GlassWallpaperPreview
    ) {
        guard state.beginManualGeneration() else {
            rebuildMenu()
            return
        }

        rebuildMenu()
        Task { @MainActor in
            do {
                _ = try await operation()
                state.finishSuccessfully()
                previewWindowController.show()
            } catch {
                let message = AppContainer.describe(error)
                container.lastErrorMessage = message
                state.finishWithFailure(message)
            }

            rebuildMenu()
        }
    }

    @objc private func showSettings() {
        settingsWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openLogs() {
        NSWorkspace.shared.open(container.logFileURL)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
