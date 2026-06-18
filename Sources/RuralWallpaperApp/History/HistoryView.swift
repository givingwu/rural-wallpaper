import AppKit
import RuralWallpaperCore
import SwiftUI

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var records: [GeneratedWallpaper] = []

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    func reload() {
        records = container.recentHistory()
    }
}

struct HistoryView: View {
    @StateObject private var viewModel: HistoryViewModel

    init(viewModel: HistoryViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("History")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(action: viewModel.reload) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .padding(16)

            Divider()

            if viewModel.records.isEmpty {
                ContentUnavailableView("No History", systemImage: "clock")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.records) { record in
                    HistoryRow(record: record)
                        .padding(.vertical, 6)
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            viewModel.reload()
        }
    }
}

private struct HistoryRow: View {
    let record: GeneratedWallpaper

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            thumbnail
                .frame(width: 96, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(record.display.friendlyName)
                        .font(.headline)
                    Spacer()
                    Text(record.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(record.words.map(\.word).joined(separator: "  "))
                    .font(.system(.body, design: .rounded).weight(.semibold))

                ForEach(record.words, id: \.word) { item in
                    Text("\(item.word): \(item.zhDefinition) · \(item.example)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                footer
            }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let url = record.finalImageURL, let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Rectangle()
                    .fill(.quaternary)
                Image(systemName: record.failureReason == nil ? "photo" : "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let failureReason = record.failureReason {
            Text(failureReason)
                .font(.caption)
                .foregroundStyle(.red)
        } else if let evaluation = record.evaluation {
            Text("Score \(evaluation.averageScore, format: .number.precision(.fractionLength(2)))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
