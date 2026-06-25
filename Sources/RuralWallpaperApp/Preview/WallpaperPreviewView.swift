import AppKit
import RuralWallpaperCore
import SwiftUI

struct WallpaperPreviewView: View {
    @ObservedObject var container: AppContainer
    let onApply: () -> Void
    let onRegenerate: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            previewContent

            Divider()

            HStack(spacing: 12) {
                message
                Spacer()
                Button(action: onCancel) {
                    Label("Cancel", systemImage: "xmark")
                }
                Button(action: onRegenerate) {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                }
                Button(action: onApply) {
                    Label("Apply", systemImage: "checkmark.circle")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(container.activeGlassPreview == nil)
            }
            .padding(14)
        }
        .frame(minWidth: 860, minHeight: 620)
    }

    @ViewBuilder
    private var previewContent: some View {
        if let preview = container.activeGlassPreview {
            HSplitView {
                previewImage(preview)
                    .frame(minWidth: 560, minHeight: 480)

                wordsPanel(preview)
                    .frame(minWidth: 260, idealWidth: 300)
            }
        } else {
            ContentUnavailableView("No Preview", systemImage: "photo")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func previewImage(_ preview: GlassWallpaperPreview) -> some View {
        ZStack {
            Color.black.opacity(0.92)
            if let image = NSImage(contentsOf: preview.previewImageURL) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(18)
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func wordsPanel(_ preview: GlassWallpaperPreview) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(preview.display.friendlyName)
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    Text(preview.createdAt, style: .time)
                    Text("\(preview.words.count) generated · \(preview.selectedWords.count) visible")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                ForEach(Array(preview.words.enumerated()), id: \.offset) { index, item in
                    Toggle(
                        isOn: selectionBinding(for: index, preview: preview)
                    ) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(item.word)
                                    .font(.title3.weight(.semibold))
                                Text("\(item.partOfSpeech) · \(item.zhDefinition)")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            Text(item.example)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(item.sourceReason)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .disabled(isSelectionControlDisabled(index: index, preview: preview))
                    .padding(.vertical, 5)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func selectionBinding(for index: Int, preview: GlassWallpaperPreview) -> Binding<Bool> {
        Binding(
            get: {
                container.activeGlassPreview?.selectedWordIndexes.contains(index)
                    ?? preview.selectedWordIndexes.contains(index)
            },
            set: { isSelected in
                do {
                    try container.setPreviewWordSelection(index: index, isSelected: isSelected)
                } catch {
                    container.lastErrorMessage = AppContainer.describe(error)
                }
            }
        )
    }

    private func isSelectionControlDisabled(index: Int, preview: GlassWallpaperPreview) -> Bool {
        let selectedIndexes = container.activeGlassPreview?.selectedWordIndexes
            ?? preview.selectedWordIndexes
        let isSelected = selectedIndexes.contains(index)
        if isSelected {
            return selectedIndexes.count <= AppSettings.wallpaperWordLimitRange.lowerBound
        }

        return selectedIndexes.count >= container.settings.wallpaperWordLimit
    }

    @ViewBuilder
    private var message: some View {
        if let message = container.lastErrorMessage {
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}
