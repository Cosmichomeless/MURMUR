import SwiftUI

struct RecorderView: View {
    let model: RecorderViewModel
    let access: MicrophoneAccess
    @ScaledMetric(relativeTo: .largeTitle) private var clockSize: CGFloat = 56

    var body: some View {
        VStack(spacing: Brand.Spacing.extraLarge) {
            if access.permission == .denied && !model.state.isCapturing {
                MicrophonePermissionView(access: access)
            } else {
                Text(Self.format(model.elapsed))
                    .font(.system(size: clockSize, weight: .light, design: .monospaced))
                    .contentTransition(.numericText())
                    .accessibilityLabel("Elapsed time")
                    .accessibilityValue(Self.format(model.elapsed))

                WaveformView(waveform: model.waveform)
                    .frame(height: 96)
                    .opacity(model.state == .paused ? 0.4 : 1)

                controls

                if case .failed(let message) = model.state {
                    VStack(spacing: Brand.Spacing.small) {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .symbolRenderingMode(.multicolor)
                            .multilineTextAlignment(.center)
                        Button("Dismiss") { model.dismissFailure() }
                            .buttonStyle(BrandPillButtonStyle())
                    }
                }
                if let notice = model.notice {
                    Text(notice)
                        .font(.footnote)
                        .foregroundStyle(Brand.onGradientSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .brandScreen()
    }

    @ViewBuilder
    private var controls: some View {
        switch model.state {
        case .idle, .failed:
            Button {
                Task { await model.start() }
            } label: {
                Image(systemName: "mic.fill")
            }
            .buttonStyle(BrandRoundButtonStyle(kind: .accent, size: 80))
            .accessibilityLabel("Start recording")
        case .recording, .paused:
            HStack(spacing: Brand.Spacing.extraLarge) {
                Button(role: .destructive) { model.discard() } label: {
                    Image(systemName: "trash.fill")
                }
                .buttonStyle(BrandRoundButtonStyle(kind: .quiet, size: 56))
                .accessibilityLabel("Discard recording")

                Button {
                    model.state == .recording ? model.pause() : model.resume()
                } label: {
                    Image(systemName: model.state == .recording ? "pause.fill" : "mic.fill")
                }
                .buttonStyle(BrandRoundButtonStyle(kind: .accent, size: 80))
                .accessibilityLabel(model.state == .recording ? "Pause recording" : "Resume recording")

                Button { model.stop() } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(BrandRoundButtonStyle(kind: .light, size: 56))
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
