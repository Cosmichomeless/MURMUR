import Foundation
@testable import MURMUR

@MainActor
final class FakeAudioSession: AudioSessionControlling {
    var microphonePermission: MicrophonePermission
    /// What the system prompt "answers" when the permission is undetermined.
    var permissionAfterPrompt: MicrophonePermission = .granted
    var activationError: (any Error)?

    private(set) var requestCount = 0
    private(set) var recordingActivations = 0
    private(set) var playbackActivations = 0
    private(set) var deactivations = 0

    init(permission: MicrophonePermission = .undetermined) {
        microphonePermission = permission
    }

    func requestMicrophonePermission() async -> MicrophonePermission {
        requestCount += 1
        microphonePermission = permissionAfterPrompt
        return microphonePermission
    }

    func activateForRecording() throws {
        if let activationError { throw activationError }
        recordingActivations += 1
    }

    func activateForPlayback() throws {
        if let activationError { throw activationError }
        playbackActivations += 1
    }

    func deactivate() {
        deactivations += 1
    }
}
