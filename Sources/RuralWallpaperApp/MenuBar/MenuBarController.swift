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
    private var automaticUpdateTask: Task<Void, Never>?

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
        startAutomaticUpdateTimer()
    }

    private func rebuildMenu() {
        updateStatusButtonImage()
        let menu = NSMenu()
        let sections = MenuBarMenuModel.sections(
            isGenerating: state.isGenerating,
            hasLastPreview: lastPreviewURL != nil
        )

        for sectionIndex in sections.indices {
            for descriptor in sections[sectionIndex].items {
                menu.addItem(menuItem(for: descriptor))
            }
            if sectionIndex < sections.index(before: sections.endIndex) {
                menu.addItem(.separator())
            }
        }

        statusItem.menu = menu
    }

    private func menuItem(for descriptor: MenuBarMenuItem) -> NSMenuItem {
        switch descriptor.role {
        case .loading:
            return loadingMenuItem()
        case .submenu:
            let item = NSMenuItem(title: descriptor.title, action: nil, keyEquivalent: "")
            item.submenu = selectedDisplayMenu()
            item.isEnabled = descriptor.isEnabled
            return item
        case .action:
            let item = NSMenuItem(
                title: descriptor.title,
                action: action(for: descriptor.title),
                keyEquivalent: keyEquivalent(for: descriptor.title)
            )
            item.target = self
            item.isEnabled = descriptor.isEnabled
            return item
        }
    }

    private func action(for title: String) -> Selector? {
        switch title {
        case "Choose Image":
            return #selector(chooseImagePreview)
        case "Generate Preview":
            return #selector(generatePreview)
        case "Cancel Generation":
            return #selector(cancelGeneration)
        case "Open Last Preview":
            return #selector(openLastPreview)
        case "Open Logs":
            return #selector(openLogs)
        case "Settings":
            return #selector(showSettings)
        case "Quit":
            return #selector(quit)
        default:
            return nil
        }
    }

    private func keyEquivalent(for title: String) -> String {
        switch title {
        case "Choose Image":
            return "o"
        case "Generate Preview":
            return "g"
        case "Cancel Generation":
            return "."
        case "Open Last Preview":
            return "p"
        case "Open Logs":
            return "l"
        case "Settings":
            return ","
        case "Quit":
            return "q"
        default:
            return ""
        }
    }

    private func updateStatusButtonImage() {
        guard let button = statusItem.button else {
            return
        }

        let symbolName = state.isGenerating ? "arrow.triangle.2.circlepath" : "photo.on.rectangle.angled"
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Rural Wallpaper")
        button.image?.isTemplate = true
    }

    private func loadingMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        item.isEnabled = false

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 14, bottom: 4, right: 14)

        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isIndeterminate = true
        spinner.startAnimation(nil)
        spinner.setFrameSize(NSSize(width: 16, height: 16))

        let label = NSTextField(labelWithString: statusTitle)
        label.font = .systemFont(ofSize: NSFont.systemFontSize)
        label.textColor = .secondaryLabelColor

        stack.addArrangedSubview(spinner)
        stack.addArrangedSubview(label)
        stack.frame = NSRect(x: 0, y: 0, width: 260, height: 28)
        item.view = stack

        return item
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

    private func startAutomaticUpdateTimer() {
        automaticUpdateTask?.cancel()
        automaticUpdateTask = Task { @MainActor [weak self] in
            self?.runAutomaticUpdateIfNeeded()

            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 60_000_000_000)
                } catch {
                    break
                }
                self?.runAutomaticUpdateIfNeeded()
            }
        }
    }

    private func runAutomaticUpdateIfNeeded(now: Date = Date()) {
        guard state.shouldRunAutomaticUpdate(settings: container.settings, now: now) else {
            return
        }
        guard state.beginManualGeneration() else {
            rebuildMenu()
            return
        }

        rebuildMenu()
        generationTask = Task { @MainActor in
            do {
                _ = try await container.runAutomaticPreviewUpdate()
                state.finishSuccessfully()
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

    deinit {
        automaticUpdateTask?.cancel()
    }
}
