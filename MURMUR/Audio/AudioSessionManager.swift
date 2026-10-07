import AVFoundation

enum AudioSessionError: Error, Equatable, LocalizedError {
    case microphoneAccessDenied
    case configurationFailed(String)

    var errorDescription: String? {
        switch self {
        case .microphoneAccessDenied:
            "MURMUR needs microphone access to record."
        case .configurationFailed(let reason):
            "The audio session could not be configured: \(reason)"
        }
    }
}

/// The single owner of `AVAudioSession` and of the microphone permission.
@MainActor
final class AudioSessionManager: AudioSessionControlling {
    private let session: AVAudioSession

    init(session: AVAudioSession = .sharedInstance()) {
        self.session = session
    }

    // MARK: - Permission

    var microphonePermission: MicrophonePermission {
        Self.permission(from: AVAudioApplication.shared.recordPermission)
    }

    func requestMicrophonePermission() async -> MicrophonePermission {
        _ = await AVAudioApplication.requestRecordPermission()
        return microphonePermission
    }

    nonisolated static func permission(from permission: AVAudioApplication.recordPermission) -> MicrophonePermission {
        switch permission {
        case .granted: .granted
        case .denied: .denied
        default: .undetermined
        }
    }

    // MARK: - Session

    func activateForRecording() throws {
        // Denial must never reach the engine: starting it without access yields silence.
        guard microphonePermission == .granted else {
            throw AudioSessionError.microphoneAccessDenied
        }
        try configure(category: .playAndRecord, mode: .default, options: Self.recordingOptions)
    }

    func activateForPlayback() throws {
        try configure(category: .playback, mode: .default, options: [])
    }

    func deactivate() {
        // Failing to deactivate (e.g. I/O still running) is harmless: the next activation reconfigures.
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Speaker output as the default route (the receiver is for calls).
    /// Bluetooth HFP microphones are left out on purpose: the option was renamed across OS versions
    /// and HFP capture is low-bandwidth (voice-call quality), which does not fit voice notes.
    private static let recordingOptions: AVAudioSession.CategoryOptions = [.defaultToSpeaker]

    private func configure(
        category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws {
        do {
            try session.setCategory(category, mode: mode, options: options)
            try session.setActive(true)
        } catch {
            throw AudioSessionError.configurationFailed(error.localizedDescription)
        }
    }
}
