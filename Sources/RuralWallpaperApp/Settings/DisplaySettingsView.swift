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
                DisplaySelection.isEnabled(displayID: display.id, settings: settings)
            },
            set: { enabled in
                DisplaySelection.update(
                    displayID: display.id,
                    enabled: enabled,
                    displays: displays,
                    settings: &settings
                )
            }
        )
    }
}
