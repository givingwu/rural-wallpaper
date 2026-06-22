import SwiftUI

struct ProviderSettingsView: View {
    @Binding var draft: ProviderSettingsDraft
    let message: String?
    let onSave: () -> Void
    let onTest: () -> Void

    var body: some View {
        Form {
            TextField("Base URL", text: $draft.baseURL)
                .textFieldStyle(.roundedBorder)
            TextField("Model", text: $draft.model)
                .textFieldStyle(.roundedBorder)
            SecureField("API Key", text: $draft.apiKey)
                .textFieldStyle(.roundedBorder)
            SecureField("Unsplash Access Key", text: $draft.unsplashAccessKey)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("Headers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $draft.additionalHeaders)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 96)
                    .border(.separator)
            }

            HStack {
                Button(action: onTest) {
                    Label("Test Connection", systemImage: "checkmark.seal")
                }
                Button(action: onSave) {
                    Label("Save Provider", systemImage: "key")
                }
                Spacer()
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}
