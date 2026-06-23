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
    private var generationTask: Task<Void, Never>?

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
        let status = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
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

        if state.isGenerating {
            let cancel = NSMenuItem(
                title: "Cancel Generation",
                action: #selector(cancelGeneration),
                keyEquivalent: "."
            )
            cancel.target = self
            menu.addItem(cancel)
        }

        let display = NSMenuItem(title: "Selected Display", action: nil, keyEquivalent: "")
        display.submenu = selectedDisplayMenu()
        menu.addItem(display)

        menu.addItem(.separator())

        let openPreview = NSMenuItem(
            title: "Open Last Preview",
            action: #selector(openLastPreview),
            keyEquivalent: "p"
        )
        openPreview.target = self
        openPreview.isEnabled = lastPreviewURL != nil
        menu.addItem(openPreview)

        let settings = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
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

    private var statusTitle: String {
        if state.isGenerating {
            return "Generating: \(container.generationProgressMessage)"
        }

        if container.generationProgressMessage == "Cancelled" {
            return "Cancelled"
        }

        return state.statusTitle == "Idle" ? "Ready" : state.statusTitle
    }

    private var lastPreviewURL: URL? {
        container.activeGlassPreview?.previewImageURL ?? container.lastGeneratedWallpaperURLs.first
    }

    private func selectedDisplayMenu() -> NSMenu {
        let menu = NSMenu()
        let displays = container.displays

        if displays.isEmpty {
            let empty = NSMenuItem(title: "No Displays", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return menu
        }

        for display in displays {
            let item = NSMenuItem(
                title: "\(display.friendlyName) (\(display.pixelSize.width)x\(display.pixelSize.height))",
                action: #selector(selectDisplay(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = display.id
            item.state = display.id == container.selectedPreviewDisplay?.id ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let refresh = NSMenuItem(title: "Refresh Displays", action: #selector(refreshDisplays), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)
        return menu
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
        generationTask = Task { @MainActor in
            do {
                _ = try await operation()
                state.finishSuccessfully()
                previewWindowController.show()
            } catch is CancellationError {
                state.finishCancelled()
            } catch {
                let message = AppContainer.describe(error)
                container.lastErrorMessage = message
                state.finishWithFailure(message)
            }

            generationTask = nil
            rebuildMenu()
        }
    }

    @objc private func cancelGeneration() {
        generationTask?.cancel()
        rebuildMenu()
    }

    @objc private func selectDisplay(_ sender: NSMenuItem) {
        guard let displayID = sender.representedObject as? String else {
            return
        }

        container.selectPreviewDisplay(id: displayID)
        rebuildMenu()
    }

    @objc private func refreshDisplays() {
        container.reloadDisplays()
        rebuildMenu()
    }

    @objc private func showSettings() {
        settingsWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openLastPreview() {
        guard let url = lastPreviewURL else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func openLogs() {
        NSWorkspace.shared.open(container.logFileURL)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
