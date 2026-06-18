import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(container: AppContainer) {
        let hostingController = NSHostingController(rootView: SettingsView(container: container))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Rural Wallpaper Settings"
        window.setContentSize(NSSize(width: 680, height: 560))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.center()

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
