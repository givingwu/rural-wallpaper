import RuralWallpaperCore
import SwiftUI

struct ProviderSettingsView: View {
    @Binding var draft: ProviderSettingsDraft
    let message: String?
    let onSave: () -> Void
    let onTest: () -> Void

    var body: some View {
        Form {
            Picker("AI CLI", selection: $draft.cliCommand) {
                Text("Codex").tag(CLIWordCommand.codex)
                Text("Claude").tag(CLIWordCommand.claude)
            }
            .pickerStyle(.segmented)

            HStack {
                Button(action: onSave) {
                    Label("Save", systemImage: "tray.and.arrow.down")
                }
                Spacer()
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}
