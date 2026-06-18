import RuralWallpaperCore
import SwiftUI

struct DisplaySettingsView: View {
    @Binding var settings: AppSettings
    let displays: [DisplayTarget]
    let onReload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button(action: onReload) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                Button {
                    settings.enabledDisplayIDs = []
                } label: {
                    Label("Enable All", systemImage: "checkmark.rectangle.stack")
                }
                Spacer()
            }

            List(displays) { display in
                Toggle(isOn: enabledBinding(for: display)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(display.friendlyName)
                        Text("\(display.pixelSize.width)x\(display.pixelSize.height) @ \(display.scale, specifier: "%.1f")x")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(20)
    }

    private func enabledBinding(for display: DisplayTarget) -> Binding<Bool> {
        Binding(
            get: {
                settings.enabledDisplayIDs.isEmpty || settings.enabledDisplayIDs.contains(display.id)
            },
            set: { enabled in
                if settings.enabledDisplayIDs.isEmpty {
                    settings.enabledDisplayIDs = Set(displays.map(\.id))
                }

                if enabled {
                    settings.enabledDisplayIDs.insert(display.id)
                } else {
                    settings.enabledDisplayIDs.remove(display.id)
                }
            }
        )
    }
}
