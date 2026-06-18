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
            TabView {
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
                .tabItem {
                    Label("Provider", systemImage: "network")
                }

                GenerationSettingsView(settings: $settings)
                    .tabItem {
                        Label("Generation", systemImage: "slider.horizontal.3")
                    }

                DisplaySettingsView(
                    settings: $settings,
                    displays: container.displays,
                    onReload: { container.reloadDisplays() }
                )
                .tabItem {
                    Label("Displays", systemImage: "display.2")
                }
            }

            Divider()

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
                .keyboardShortcut("s", modifiers: .command)
            }
            .padding(16)
        }
        .frame(minWidth: 640, minHeight: 520)
    }
}
