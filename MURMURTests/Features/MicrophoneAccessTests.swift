import AVFoundation
import Testing
@testable import MURMUR

@MainActor
struct MicrophoneAccessTests {
    @Test func undeterminedPermissionIsRequestedThenSessionActivated() async {
        let session = FakeAudioSession(permission: .undetermined)
        session.permissionAfterPrompt = .granted
        let access = MicrophoneAccess(session: session)

        let canRecord = await access.prepareForRecording()

        #expect(canRecord)
        #expect(access.permission == .granted)
        #expect(session.requestCount == 1)
        #expect(session.recordingActivations == 1)
    }

    @Test func deniedPromptDoesNotActivateTheSession() async {
        let session = FakeAudioSession(permission: .undetermined)
        session.permissionAfterPrompt = .denied
        let access = MicrophoneAccess(session: session)

        let canRecord = await access.prepareForRecording()

        #expect(!canRecord)
        #expect(access.permission == .denied)
        #expect(session.recordingActivations == 0)
    }

    @Test func alreadyDeniedNeverPromptsAgainNorActivates() async {
        let session = FakeAudioSession(permission: .denied)
        let access = MicrophoneAccess(session: session)

        let canRecord = await access.prepareForRecording()

        #expect(!canRecord)
        #expect(session.requestCount == 0)
        #expect(session.recordingActivations == 0)
    }

    @Test func alreadyGrantedActivatesWithoutPrompting() async {
        let session = FakeAudioSession(permission: .granted)
        let access = MicrophoneAccess(session: session)

        #expect(await access.prepareForRecording())
        #expect(session.requestCount == 0)
        #expect(session.recordingActivations == 1)
    }

    @Test func activationFailureBlocksRecordingAndExposesTheReason() async {
        let session = FakeAudioSession(permission: .granted)
        session.activationError = AudioSessionError.configurationFailed("busy")
        let access = MicrophoneAccess(session: session)

        let canRecord = await access.prepareForRecording()

        #expect(!canRecord)
        #expect(access.sessionError?.contains("busy") == true)
    }

    @Test func refreshPicksUpAChangeMadeInSettings() {
        let session = FakeAudioSession(permission: .denied)
        let access = MicrophoneAccess(session: session)

        session.microphonePermission = .granted
        access.refresh()

        #expect(access.permission == .granted)
    }

    @Test func reactivateActivatesTheSessionAgain() throws {
        let session = FakeAudioSession(permission: .granted)
        let access = MicrophoneAccess(session: session)

        try access.reactivate()

        #expect(session.recordingActivations == 1)
    }

    @Test func reactivateFailsWhenThePermissionWasWithdrawn() {
        let session = FakeAudioSession(permission: .granted)
        let access = MicrophoneAccess(session: session)
        session.microphonePermission = .denied

        #expect(throws: AudioSessionError.microphoneAccessDenied) { try access.reactivate() }
        #expect(session.recordingActivations == 0)
    }

    @Test func systemPermissionMapsToAppPermission() {
        #expect(AudioSessionManager.permission(from: .granted) == .granted)
        #expect(AudioSessionManager.permission(from: .denied) == .denied)
        #expect(AudioSessionManager.permission(from: .undetermined) == .undetermined)
    }
}
