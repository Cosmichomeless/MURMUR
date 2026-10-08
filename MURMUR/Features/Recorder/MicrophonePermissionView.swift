import SwiftUI

/// Shows the microphone permission and offers the right action for each state.
struct MicrophonePermissionView: View {
    let access: MicrophoneAccess
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: Brand.Spacing.medium) {
            Image(systemName: symbol)
                .font(.system(size: 40))
                .foregroundStyle(access.permission == .granted ? Brand.onGradient : Brand.coral)
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Brand.onGradientSecondary)
                .multilineTextAlignment(.center)

            switch access.permission {
            case .undetermined:
                Button("Allow microphone") {
                    Task { _ = await access.prepareForRecording() }
                }
                .buttonStyle(BrandPillButtonStyle())
            case .denied:
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .buttonStyle(BrandPillButtonStyle())
            case .granted:
                EmptyView()
            }

            if let error = access.sessionError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .symbolRenderingMode(.multicolor)
                    .multilineTextAlignment(.center)
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
