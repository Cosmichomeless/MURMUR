import Foundation

/// Microphone authorization as the UI needs to see it.
enum MicrophonePermission: Sendable, Equatable {
    case undetermined
    case granted
    case denied
}

/// Boundary around `AVAudioSession` and the microphone permission.
///
/// Only the implementation of this protocol imports `AVAudioSession`. Recorder and player ask for a
/// *purpose* (record / play back) and never configure categories themselves, so the session has a
/// single owner.
@MainActor
protocol AudioSessionControlling: AnyObject {
    var microphonePermission: MicrophonePermission { get }

    /// Shows the system prompt when the permission is still undetermined.
    func requestMicrophonePermission() async -> MicrophonePermission

    /// Configures and activates the session for capture.
    func activateForRecording() throws

    /// Configures and activates the session for playback.
    func activateForPlayback() throws

    /// Deactivates the session and lets other apps resume their audio.
    func deactivate()
}
