import SwiftUI

/// Shows the microphone permission and offers the right action for each state.
struct MicrophonePermissionView: View {
    let access: MicrophoneAccess
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 40))
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            switch access.permission {
            case .undetermined:
                Button("Allow microphone") {
                    Task { _ = await access.prepareForRecording() }
                }
                .buttonStyle(.borderedProminent)
            case .denied:
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            case .granted:
                EmptyView()
            }

            if let error = access.sessionError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .accessibilityElement(children: .contain)
    }

    private var symbol: String {
        switch access.permission {
        case .undetermined: "mic.badge.plus"
        case .granted: "mic.fill"
        case .denied: "mic.slash.fill"
        }
    }

    private var tint: Color {
        switch access.permission {
        case .undetermined: .orange
        case .granted: .green
        case .denied: .red
        }
    }

    private var title: String {
        switch access.permission {
        case .undetermined: "Microphone access needed"
        case .granted: "Microphone ready"
        case .denied: "Microphone access denied"
        }
    }

    private var message: String {
        switch access.permission {
        case .undetermined: "MURMUR records voice notes with the microphone. Nothing leaves your device."
        case .granted: "You can record voice notes."
        case .denied: "Recording is disabled. Allow microphone access for MURMUR in Settings to record."
        }
    }
}
