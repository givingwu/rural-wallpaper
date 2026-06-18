import AppKit
import SwiftUI

@MainActor
final class HistoryWindowController: NSWindowController {
    private let viewModel: HistoryViewModel

    init(container: AppContainer) {
        let viewModel = HistoryViewModel(container: container)
        self.viewModel = viewModel

        let hostingController = NSHostingController(rootView: HistoryView(viewModel: viewModel))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Rural Wallpaper History"
        window.setContentSize(NSSize(width: 760, height: 560))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.center()

        super.init(window: window)
    }

    func reload() {
        viewModel.reload()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
