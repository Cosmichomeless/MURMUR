import SwiftUI

struct RecordingRow: View {
    let recording: Recording
    /// What a search found in the transcript, shown under the title.
    var moment: RecordingSearchResult.Moment?
    /// `false` when the note came from iCloud and its audio has not been downloaded yet.
    var audioAvailable = true

    var body: some View {
        HStack(spacing: Brand.Spacing.medium) {
            // The icon's gradient tile with its waveform motif.
            Image(systemName: "waveform")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Brand.gradient, in: RoundedRectangle(cornerRadius: Brand.Radius.tile))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(recording.title)
                    .font(.headline)
                    .lineLimit(1)
                if let moment {
                    Text(moment.snippet)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !recording.tags.isEmpty {
                    Text(recording.tags.map { "#\($0)" }.joined(separator: " "))
                        .font(.caption)
                        .foregroundStyle(Brand.coral)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(DurationFormat.clock(recording.duration))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                if !audioAvailable {
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                if let time = moment?.time {
                    Label(DurationFormat.clock(time), systemImage: "play.circle.fill")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Brand.coral)
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(recording.title)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        var parts = ["\(DurationFormat.clock(recording.duration)), \(recording.createdAt.formatted(date: .abbreviated, time: .shortened))"]
        if !recording.tags.isEmpty { parts.append(recording.tags.joined(separator: ", ")) }
        if let moment { parts.append(moment.snippet) }
        if !audioAvailable { parts.append(String(localized: "Audio not downloaded yet")) }
        return parts.joined(separator: ". ")
    }
}
