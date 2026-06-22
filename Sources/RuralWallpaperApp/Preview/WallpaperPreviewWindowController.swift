import AppKit
import SwiftUI

@MainActor
final class WallpaperPreviewWindowController: NSWindowController {
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container

        let window = NSWindow()
        window.title = "Rural Wallpaper Preview"
        window.setContentSize(NSSize(width: 980, height: 680))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.center()

        super.init(window: window)

        window.contentViewController = NSHostingController(
            rootView: WallpaperPreviewView(
                container: container,
                onApply: { [weak self] in
                    self?.apply()
                },
                onRegenerate: { [weak self] in
                    self?.regenerate()
                },
                onCancel: { [weak self] in
                    self?.close()
                }
            )
        )
    }

    func show() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func apply() {
        do {
            try container.applyGlassPreview()
            close()
        } catch {
            container.lastErrorMessage = AppContainer.describe(error)
        }
    }

    private func regenerate() {
        Task { @MainActor in
            do {
                _ = try await container.generateGlassPreview()
            } catch {
                container.lastErrorMessage = AppContainer.describe(error)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
