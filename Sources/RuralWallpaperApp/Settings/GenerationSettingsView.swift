import RuralWallpaperCore
import SwiftUI

struct GenerationSettingsView: View {
    @Binding var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Auto Update & Apply", isOn: $settings.autoUpdateEnabled)

            Stepper(
                value: $settings.vocabularyWordCount,
                in: AppSettings.vocabularyWordCountRange
            ) {
                labeledValue("Generated Words", "\(settings.vocabularyWordCount)")
            }

            Stepper(
                value: visibleWordLimitBinding,
                in: visibleWordLimitRange
            ) {
                labeledValue("Visible on Wallpaper", "\(settings.wallpaperWordLimit)")
            }

            Stepper(value: $settings.refreshIntervalHours, in: 1...168) {
                labeledValue("Refresh", "\(settings.refreshIntervalHours) h")
            }

            Stepper(value: $settings.maxBackgroundAttempts, in: 1...8) {
                labeledValue("Background Attempts", "\(settings.maxBackgroundAttempts)")
            }

            Stepper(value: $settings.maxLayoutCandidates, in: 1...10) {
                labeledValue("Layout Candidates", "\(settings.maxLayoutCandidates)")
            }

            HStack {
                Text("Minimum Score")
                Slider(value: $settings.minimumScore, in: 0.5...0.98, step: 0.01)
                Text(settings.minimumScore, format: .number.precision(.fractionLength(2)))
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }

            Stepper(value: $settings.historyLimitPerDisplay, in: 5...100) {
                labeledValue("History Per Display", "\(settings.historyLimitPerDisplay)")
            }
        }
        .onChange(of: settings.vocabularyWordCount) { _, newValue in
            settings.wallpaperWordLimit = min(
                settings.wallpaperWordLimit,
                min(newValue, AppSettings.wallpaperWordLimitRange.upperBound)
            )
        }
    }

    private var visibleWordLimitRange: ClosedRange<Int> {
        AppSettings.wallpaperWordLimitRange.lowerBound...min(
            settings.vocabularyWordCount,
            AppSettings.wallpaperWordLimitRange.upperBound
        )
    }

    private var visibleWordLimitBinding: Binding<Int> {
        Binding(
            get: { settings.wallpaperWordLimit },
            set: { value in
                settings.wallpaperWordLimit = min(
                    max(value, visibleWordLimitRange.lowerBound),
                    visibleWordLimitRange.upperBound
                )
            }
        )
    }

    private func labeledValue(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
