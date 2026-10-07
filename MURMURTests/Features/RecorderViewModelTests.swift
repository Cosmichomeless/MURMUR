import Foundation
import Testing
@testable import MURMUR

@MainActor
struct RecorderViewModelTests {
    struct Harness {
        let session: FakeAudioSession
        let recorder: FakeAudioRecorder
        let model: RecorderViewModel
        let saved: SavedBox
    }

    @MainActor
    final class SavedBox {
        var audios: [RecordedAudio] = []
        var error: (any Error)?
    }

    private func makeHarness(permission: MicrophonePermission = .granted) -> Harness {
        let session = FakeAudioSession(permission: permission)
        let recorder = FakeAudioRecorder()
        let saved = SavedBox()
        let model = RecorderViewModel(
            access: MicrophoneAccess(session: session),
            recorder: recorder,
            save: { audio in
                if let error = saved.error { throw error }
                saved.audios.append(audio)
            }
        )
        return Harness(session: session, recorder: recorder, model: model, saved: saved)
    }

    /// Lets the consumer task drain the samples that were emitted.
    private func settle() async {
        for _ in 0..<5 { await Task.yield() }
    }

    @Test func startBeginsRecording() async {
        let h = makeHarness()
        await h.model.start()

        #expect(h.model.state == .recording)
        #expect(h.recorder.startCount == 1)
        #expect(h.session.recordingActivations == 1)
    }

    @Test func deniedPermissionNeverStartsTheRecorder() async {
        let h = makeHarness(permission: .denied)
        await h.model.start()

        #expect(h.model.state == .idle)
        #expect(h.recorder.startCount == 0)
        #expect(h.session.recordingActivations == 0)
    }

    @Test func elapsedFollowsTheSamples() async {
        let h = makeHarness()
        await h.model.start()

        h.recorder.emit(duration: 0.5)
        h.recorder.emit(duration: 1.25)
        await settle()

        #expect(h.model.elapsed == 1.25)
    }

    @Test func levelsFeedTheLiveWaveformAndStartClearsIt() async {
        let h = makeHarness()
        await h.model.start()
        h.recorder.emit(duration: 0.05, level: 0.2)
        h.recorder.emit(duration: 0.10, level: 0.8)
        await settle()

        #expect(h.model.waveform.count == 2)
        #expect(h.model.waveform[1] == 0.8)

        h.model.discard()
        await h.model.start()
        #expect(h.model.waveform.count == 0)
    }

    @Test func pauseAndResumeDriveTheRecorder() async {
        let h = makeHarness()
        await h.model.start()

        h.model.pause()
        #expect(h.model.state == .paused)
        #expect(h.recorder.pauseCount == 1)

        h.model.resume()
        #expect(h.model.state == .recording)
        #expect(h.recorder.resumeCount == 1)
    }

    @Test func stopSavesTheRecordingAndReleasesTheSession() async {
        let h = makeHarness()
        await h.model.start()
        h.recorder.emit(duration: 2)
        await settle()

        h.model.stop()

        #expect(h.model.state == .idle)
        #expect(h.model.elapsed == 0)
        #expect(h.saved.audios == [h.recorder.recorded])
        #expect(h.model.savedCount == 1)
        #expect(h.session.deactivations == 1)
    }

    @Test func discardSavesNothingAndTellsTheRecorderToCleanUp() async {
        let h = makeHarness()
        await h.model.start()

        h.model.discard()

        #expect(h.model.state == .idle)
        #expect(h.recorder.discardCount == 1)
        #expect(h.saved.audios.isEmpty)
        #expect(h.session.deactivations == 1)
    }

    @Test func stopWithoutRecordingDoesNothing() {
        let h = makeHarness()
        h.model.stop()

        #expect(h.model.state == .idle)
        #expect(h.recorder.stopCount == 0)
    }

    @Test func saveFailureSurfacesAsFailedState() async {
        let h = makeHarness()
        h.saved.error = CocoaError(.fileWriteOutOfSpace)
        await h.model.start()

        h.model.stop()

        guard case .failed = h.model.state else {
            Issue.record("expected a failed state, got \(h.model.state)")
            return
        }
        #expect(h.session.deactivations == 1)
    }

    @Test func startFailureReleasesTheSessionAndFails() async {
        let h = makeHarness()
        h.recorder.startError = AudioRecorderError.invalidInputFormat

        await h.model.start()

        guard case .failed = h.model.state else {
            Issue.record("expected a failed state, got \(h.model.state)")
            return
        }
        #expect(h.session.deactivations == 1)
    }

    @Test func streamFailureKeepsWhatWasCaptured() async {
        let h = makeHarness()
        await h.model.start()
        h.recorder.emit(duration: 3)

        h.recorder.failStream(with: CocoaError(.fileWriteOutOfSpace))
        await settle()

        #expect(h.model.state == .idle)
        #expect(h.saved.audios == [h.recorder.recorded])
        #expect(h.model.notice != nil)
        #expect(h.session.deactivations == 1)
    }

    @Test func canRecordAgainAfterAFailure() async {
        let h = makeHarness()
        h.recorder.startError = AudioRecorderError.invalidInputFormat
        await h.model.start()

        h.recorder.startError = nil
        await h.model.start()

        #expect(h.model.state == .recording)
    }
}
