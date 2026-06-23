import AppKit
import RuralWallpaperCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var container: AppContainer
    @State private var settings: AppSettings
    @State private var provider: ProviderSettingsDraft

    init(container: AppContainer) {
        self.container = container
        _settings = State(initialValue: container.settings)
        _provider = State(initialValue: container.providerSettings)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    settingsGroup(title: "AI Provider", systemImage: "sparkles") {
                        ProviderSettingsView(
                            draft: $provider,
                            message: container.lastErrorMessage,
                            onSave: { container.saveProviderSettings(provider) },
                            onTest: {
                                Task {
                                    await container.testProviderConnection(provider)
                                }
                            }
                        )
                    }

                    settingsGroup(title: "Display", systemImage: "display.2") {
                        DisplaySettingsView(
                            settings: $settings,
                            displays: container.displays,
                            onReload: { container.reloadDisplays() }
                        )
                    }

                    settingsGroup(title: "Generation", systemImage: "slider.horizontal.3") {
                        GenerationSettingsView(settings: $settings)
                    }

                    settingsGroup(title: "Logs & Storage", systemImage: "doc.text.magnifyingglass") {
                        VStack(alignment: .leading, spacing: 12) {
                            labeledValue("Log File", container.logFileURL.path)
                            Button {
                                NSWorkspace.shared.open(container.logFileURL)
                            } label: {
                                Label("Open Logs", systemImage: "arrow.up.forward.app")
                            }
                        }
                    }

                    settingsGroup(title: "About", systemImage: "info.circle") {
                        VStack(alignment: .leading, spacing: 8) {
                            labeledValue("App", "Rural Wallpaper")
                            labeledValue("Version", "0.1.0")
                            labeledValue("Provider", "\(provider.cliCommand.rawValue)")
                            Text("Current flow reads your desktop wallpaper, extracts English words with a local CLI, renders a glass preview, and applies it only after confirmation.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            footer
        }
        .frame(minWidth: 720, minHeight: 680)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Rural Wallpaper Settings")
                .font(.title2.weight(.semibold))
            Text("Configure the preview loop, target display, local AI CLI, and diagnostics.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack {
            if let message = container.lastErrorMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                settings = container.settings
                provider = container.providerSettings
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }

            Button {
                container.saveGenerationSettings(settings)
                container.saveProviderSettings(provider)
            } label: {
                Label("Save", systemImage: "tray.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("s", modifiers: .command)
        }
        .padding(16)
    }

    private func settingsGroup<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        }
    }

    private func labeledValue(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
            Spacer(minLength: 24)
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .font(.callout)
    }
}
