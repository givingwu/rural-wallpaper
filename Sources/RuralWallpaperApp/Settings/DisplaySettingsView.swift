import RuralWallpaperCore
import Foundation
import SwiftUI

struct DisplaySettingsView: View {
    @Binding var settings: AppSettings
    let displays: [DisplayTarget]
    let onReload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if displays.isEmpty {
                Text("No displays available.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Preview Target", selection: selectedPreviewDisplayBinding) {
                    ForEach(displays) { display in
                        Text(displayLabel(display)).tag(display.id)
                    }
                }
            }

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

            VStack(alignment: .leading, spacing: 10) {
                Text("Enabled Displays")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(displays) { display in
                    displayToggle(display)
                }
            }
        }
    }

    private func displayToggle(_ display: DisplayTarget) -> some View {
        Toggle(isOn: enabledBinding(for: display)) {
            VStack(alignment: .leading, spacing: 3) {
                Text(display.friendlyName)
                Text(displayLabel(display))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var selectedPreviewDisplayBinding: Binding<String> {
        Binding(
            get: {
                let selectedID = settings.selectedPreviewDisplayID
                if let selectedID, displays.contains(where: { $0.id == selectedID }) {
                    return selectedID
                }

                return displays.first(where: \.isMain)?.id ?? displays.first?.id ?? ""
            },
            set: { selectedID in
                guard displays.contains(where: { $0.id == selectedID }) else {
                    return
                }

                settings.selectedPreviewDisplayID = selectedID
            }
        )
    }

    private func displayLabel(_ display: DisplayTarget) -> String {
        "\(display.pixelSize.width)x\(display.pixelSize.height) @ \(String(format: "%.1f", display.scale))x"
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
