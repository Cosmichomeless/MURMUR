import SwiftUI

struct RecordingRow: View {
    let recording: Recording

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
                Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(DurationFormat.clock(recording.duration))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(recording.title)
        .accessibilityValue("\(DurationFormat.clock(recording.duration)), \(recording.createdAt.formatted(date: .abbreviated, time: .shortened))")
    }
}
