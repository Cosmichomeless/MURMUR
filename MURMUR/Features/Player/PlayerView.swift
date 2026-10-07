import SwiftUI

/// Plays one recording: waveform with progress, a seek slider and play / pause.
struct PlayerView: View {
    let recording: Recording
    let fileURL: URL
    let model: PlayerViewModel

    /// The position being dragged to. While set, it wins over the player's own position.
    @State private var scrubTime: TimeInterval?

    private var shownTime: TimeInterval { scrubTime ?? model.currentTime }
    private var shownProgress: Double {
        model.duration > 0 ? min(max(shownTime / model.duration, 0), 1) : 0
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 4) {
                Text(recording.createdAt.formatted(date: .complete, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            StaticWaveformView(levels: recording.waveform, progress: shownProgress)
                .frame(height: 96)

            VStack(spacing: 4) {
                Slider(
                    value: Binding(get: { shownTime }, set: { scrubTime = $0 }),
                    in: 0...max(model.duration, 0.1)
                ) { editing in
                    if !editing, let time = scrubTime {
                        model.seek(to: time)
                        scrubTime = nil
                    }
                }
                .disabled(!model.isLoaded)
                .accessibilityLabel("Playback position")
                .accessibilityValue("\(DurationFormat.clock(shownTime)) of \(DurationFormat.clock(model.duration))")

                HStack {
                    Text(DurationFormat.clock(shownTime))
                    Spacer()
                    Text(DurationFormat.clock(model.duration))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            Button {
                model.togglePlayPause()
            } label: {
                Image(systemName: playbackSymbol)
                    .font(.system(size: 64))
            }
            .disabled(!model.isLoaded)
            .accessibilityLabel(playbackLabel)

            if let message = model.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
        .navigationTitle(recording.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.load(url: fileURL) }
        .onDisappear { model.stop() }
    }

    private var playbackSymbol: String {
        switch model.state {
        case .playing: "pause.circle.fill"
        case .finished: "arrow.counterclockwise.circle.fill"
        case .idle, .paused: "play.circle.fill"
        }
    }

    private var playbackLabel: String {
        switch model.state {
        case .playing: "Pause"
        case .finished: "Play again"
        case .idle, .paused: "Play"
        }
    }
}
