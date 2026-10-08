#if DEBUG
import Foundation

/// Demo-mode session: recording is always allowed (nothing touches the microphone), playback still
/// goes through the real session so the sound comes out of the simulator.
@MainActor
final class DemoSession: AudioSessionControlling {
    private let playback: any AudioSessionControlling

    init(playback: any AudioSessionControlling) {
        self.playback = playback
    }

    var microphonePermission: MicrophonePermission { .granted }

    func requestMicrophonePermission() async -> MicrophonePermission { .granted }

    func activateForRecording() throws {}

    func activateForPlayback() throws { try playback.activateForPlayback() }

    func deactivate() { playback.deactivate() }
}
#endif
