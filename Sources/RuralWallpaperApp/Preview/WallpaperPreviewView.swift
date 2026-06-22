import AppKit
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
                Text(preview.createdAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(preview.words, id: \.word) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.word)
                            .font(.title3.weight(.semibold))
                        Text("\(item.partOfSpeech) · \(item.zhDefinition)")
                            .font(.callout)
                        Text(item.example)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.sourceReason)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
