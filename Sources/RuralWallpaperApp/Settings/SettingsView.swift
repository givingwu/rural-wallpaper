import AppKit
import RuralWallpaperCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var container: AppContainer
    @State private var settings: AppSettings
    @State private var provider: ProviderSettingsDraft
    @State private var selectedSection: SettingsSection = .generation

    init(container: AppContainer) {
        self.container = container
        _settings = State(initialValue: container.settings)
        _provider = State(initialValue: container.providerSettings)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        contentHeader
                        selectedContent
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()

                footer
            }
            .background(.regularMaterial)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 860, minHeight: 660)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Rural Wallpaper")
                    .font(.title3.weight(.semibold))
                Text("Settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)

            VStack(spacing: 6) {
                ForEach(SettingsSection.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: section.systemImage)
                                .frame(width: 18)
                            Text(section.title)
                            Spacer()
                        }
                        .font(.callout.weight(selectedSection == section ? .semibold : .regular))
                        .foregroundStyle(selectedSection == section ? .primary : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            if selectedSection == section {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(.quaternary.opacity(0.55))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding(14)
        .frame(width: 220)
        .background(.ultraThinMaterial)
    }

    private var contentHeader: some View {
        Label(selectedSection.title, systemImage: selectedSection.systemImage)
            .font(.title2.weight(.semibold))
            .labelStyle(.titleAndIcon)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedSection {
        case .provider:
            settingsGroup {
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
        case .display:
            settingsGroup {
                DisplaySettingsView(
                    settings: $settings,
                    displays: container.displays,
                    onReload: { container.reloadDisplays() }
                )
            }
        case .generation:
            settingsGroup {
                GenerationSettingsView(settings: $settings)
            }
        case .logs:
            settingsGroup {
                VStack(alignment: .leading, spacing: 12) {
                    labeledValue("Log File", container.logFileURL.path)
                    Button {
                        NSWorkspace.shared.open(container.logFileURL)
                    } label: {
                        Label("Open Logs", systemImage: "arrow.up.forward.app")
                    }
                }
            }
        case .about:
            settingsGroup {
                VStack(alignment: .leading, spacing: 10) {
                    labeledValue("App", "Rural Wallpaper")
                    labeledValue("Version", "0.1.0")
                    labeledValue("Provider", "\(provider.cliCommand.rawValue)")
                }
            }
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
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

private enum SettingsSection: String, CaseIterable, Identifiable {
    case provider
    case display
    case generation
    case logs
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .provider:
            return "AI Provider"
        case .display:
            return "Display"
        case .generation:
            return "Generation"
        case .logs:
            return "Logs & Storage"
        case .about:
            return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .provider:
            return "sparkles"
        case .display:
            return "display.2"
        case .generation:
            return "slider.horizontal.3"
        case .logs:
            return "doc.text.magnifyingglass"
        case .about:
            return "info.circle"
        }
    }
}
