import RuralWallpaperCore
import SwiftUI

struct ProviderSettingsView: View {
    @Binding var draft: ProviderSettingsDraft
    let message: String?
    let onSave: () -> Void
    let onTest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("AI CLI", selection: $draft.cliCommand) {
                Text("Codex").tag(CLIWordCommand.codex)
                Text("Claude").tag(CLIWordCommand.claude)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                Button(action: onSave) {
                    Label("Save", systemImage: "tray.and.arrow.down")
                }
                Button(action: onTest) {
                    Label("Test", systemImage: "checkmark.seal")
                }
            }

            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }
}
