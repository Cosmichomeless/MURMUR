import SwiftUI

struct RecorderView: View {
    let model: RecorderViewModel
    let access: MicrophoneAccess

    var body: some View {
        VStack(spacing: 32) {
            if access.permission == .denied && !model.state.isCapturing {
                MicrophonePermissionView(access: access)
            } else {
                Text(Self.format(model.elapsed))
                    .font(.system(size: 56, weight: .light, design: .monospaced))
                    .contentTransition(.numericText())
                    .accessibilityLabel("Elapsed time")
                    .accessibilityValue(Self.format(model.elapsed))

                WaveformView(waveform: model.waveform)
                    .frame(height: 96)
                    .opacity(model.state == .paused ? 0.4 : 1)

                controls

                if case .failed(let message) = model.state {
                    VStack(spacing: 8) {
                        Text(message).font(.footnote).foregroundStyle(.red)
                        Button("Dismiss") { model.dismissFailure() }
                    }
                }
                if let notice = model.notice {
                    Text(notice).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private var controls: some View {
        switch model.state {
        case .idle, .failed:
            Button {
                Task { await model.start() }
            } label: {
                Image(systemName: "mic.circle.fill").font(.system(size: 72))
            }
            .accessibilityLabel("Start recording")
        case .recording, .paused:
            HStack(spacing: 32) {
                Button(role: .destructive) { model.discard() } label: {
                    Image(systemName: "trash.circle.fill").font(.system(size: 48))
                }
                .accessibilityLabel("Discard recording")

                Button {
                    model.state == .recording ? model.pause() : model.resume()
                } label: {
                    Image(systemName: model.state == .recording ? "pause.circle.fill" : "record.circle.fill")
                        .font(.system(size: 72))
                }
                .accessibilityLabel(model.state == .recording ? "Pause recording" : "Resume recording")

                Button { model.stop() } label: {
                    Image(systemName: "stop.circle.fill").font(.system(size: 48))
                }
                .accessibilityLabel("Stop and save")
            }
        }
    }

    static func format(_ interval: TimeInterval) -> String {
        let tenths = Int(interval * 10)
        let minutes = tenths / 600
        let seconds = (tenths / 10) % 60
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths % 10)
    }
}
