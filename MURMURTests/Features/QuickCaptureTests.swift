import Foundation
import Testing
@testable import MURMUR

@MainActor
struct QuickCaptureCoordinatorTests {
    @Test func deliversToTheHandlerRightAway() {
        let coordinator = QuickCaptureCoordinator()
        var received: [QuickCaptureCommand] = []
        coordinator.attach { command, _ in received.append(command) }

        coordinator.send(.start)
        coordinator.send(.stop)

        #expect(received == [.start, .stop])
    }

    @Test func keepsACommandThatArrivesBeforeTheAppIsListening() {
        let coordinator = QuickCaptureCoordinator()
        coordinator.send(.start)

        var received: [QuickCaptureCommand] = []
        coordinator.attach { command, _ in received.append(command) }

        #expect(received == [.start])
    }

    @Test func deliversAQueuedCommandOnlyOnce() {
        let coordinator = QuickCaptureCoordinator()
        coordinator.send(.start)
        var count = 0
        coordinator.attach { _, _ in count += 1 }
        coordinator.attach { _, _ in count += 1 }

        #expect(count == 1)
    }

    @Test func dropsACommandNobodyPickedUpInTime() {
        let coordinator = QuickCaptureCoordinator()
        coordinator.send(.start, at: .now - QuickCaptureCoordinator.staleAfter - .seconds(1))

        var received: [QuickCaptureCommand] = []
        coordinator.attach { command, _ in received.append(command) }

        #expect(received.isEmpty)
    }

    @Test func passesTheMomentOfTheRequestAlong() {
        let coordinator = QuickCaptureCoordinator()
        let asked = ContinuousClock.now - .seconds(2)
        coordinator.send(.start, at: asked)

        var instant: ContinuousClock.Instant?
        coordinator.attach { _, at in instant = at }

        #expect(instant == asked)
    }

    @Test func stopsDeliveringAfterDetach() {
        let coordinator = QuickCaptureCoordinator()
        var count = 0
        coordinator.attach { _, _ in count += 1 }
        coordinator.detach()
        coordinator.send(.stop)

        #expect(count == 0)
    }
}

@MainActor
struct QuickCaptureRecorderTests {
    struct Harness {
        let recorder: FakeAudioRecorder
        let activity: FakeRecordingActivity
        let saved: Saved
        let model: RecorderViewModel
    }

    @MainActor
    final class Saved {
        var count = 0
    }

    private func makeHarness(permission: MicrophonePermission = .granted) -> Harness {
        let recorder = FakeAudioRecorder()
        let activity = FakeRecordingActivity()
        let saved = Saved()
        let model = RecorderViewModel(
            access: MicrophoneAccess(session: FakeAudioSession(permission: permission)),
            recorder: recorder,
            activity: activity,
            save: { _ in saved.count += 1 }
        )
        return Harness(recorder: recorder, activity: activity, saved: saved, model: model)
    }

    private func settle() async {
        for _ in 0..<5 { await Task.yield() }
    }

    // MARK: Commands

    @Test func aStartCommandStartsRecording() async {
        let h = makeHarness()
        await h.model.handle(.start, requestedAt: .now)?.value

        #expect(h.model.state == .recording)
        #expect(h.recorder.startCount == 1)
    }

    @Test func aStartCommandStopsPlaybackFirst() async {
        let h = makeHarness()
        var stoppedPlayback = false
        await h.model.handle(.start, requestedAt: .now) { stoppedPlayback = true }?.value

        #expect(stoppedPlayback)
    }

    @Test func aStartCommandWhileRecordingDoesNothing() async {
        let h = makeHarness()
        await h.model.start()
        var stoppedPlayback = false
        let task = h.model.handle(.start, requestedAt: .now) { stoppedPlayback = true }

        #expect(task == nil)
        #expect(!stoppedPlayback)
        #expect(h.recorder.startCount == 1)
    }

    @Test func aStartCommandWithoutMicrophoneAccessDoesNotRecord() async {
        let h = makeHarness(permission: .denied)
        await h.model.handle(.start, requestedAt: .now)?.value

        #expect(h.model.state == .idle)
        #expect(h.recorder.startCount == 0)
        #expect(h.activity.calls.isEmpty)
    }

    @Test func aStopCommandSavesTheRecording() async {
        let h = makeHarness()
        await h.model.start()
        h.model.handle(.stop, requestedAt: .now)

        #expect(h.model.state == .idle)
        #expect(h.saved.count == 1)
    }

    @Test func aStopCommandWithNothingRecordingDoesNothing() {
        let h = makeHarness()
        h.model.handle(.stop, requestedAt: .now)

        #expect(h.saved.count == 0)
        #expect(h.recorder.stopCount == 0)
    }

    // MARK: Live Activity

    @Test func theActivityFollowsTheRecording() async {
        let h = makeHarness()
        await h.model.start()
        h.recorder.emit(duration: 4.2)
        await settle()
        h.model.pause()
        h.model.resume()
        h.model.stop()

        #expect(h.activity.calls == [.started, .paused(4.2), .resumed(4.2), .ended])
    }

    @Test func discardingEndsTheActivity() async {
        let h = makeHarness()
        await h.model.start()
        h.model.discard()

        #expect(h.activity.calls == [.started, .ended])
    }

    @Test func aFailedSaveStillEndsTheActivity() async {
        let h = makeHarness()
        h.recorder.stopError = CocoaError(.fileWriteOutOfSpace)
        await h.model.start()
        h.model.stop()

        #expect(h.activity.calls == [.started, .ended])
    }

    @Test func aCaptureThatBreaksEndsTheActivity() async {
        let h = makeHarness()
        await h.model.start()
        h.recorder.failStream(with: CocoaError(.fileWriteOutOfSpace))
        await settle()

        #expect(h.activity.calls == [.started, .ended])
        #expect(h.saved.count == 1)
    }

    // MARK: Time to first audio

    @Test func measuresTheTimeFromTheRequestToTheFirstAudio() async {
        let h = makeHarness()
        let asked = ContinuousClock.now - .milliseconds(300)
        await h.model.start(requestedAt: asked)
        #expect(h.model.startLatency == nil)

        h.recorder.emit(duration: 0.05)
        await settle()

        let latency = try? #require(h.model.startLatency)
        let sinceTheRequest = asked.duration(to: .now)
        #expect((latency ?? .zero) >= .milliseconds(300))
        // It cannot exceed the time since the request, however slow the machine is. A fixed bound in
        // seconds would measure the CI runner, not the app.
        #expect((latency ?? .seconds(99)) <= sinceTheRequest)
    }

    @Test func measuresOnlyTheFirstAudio() async {
        let h = makeHarness()
        await h.model.start(requestedAt: .now)
        h.recorder.emit(duration: 0.05)
        await settle()
        let first = h.model.startLatency
        h.recorder.emit(duration: 0.10)
        await settle()

        #expect(first != nil)
        #expect(h.model.startLatency == first)
    }

    @Test func aNewRecordingStartsANewMeasurement() async {
        let h = makeHarness()
        await h.model.start()
        h.recorder.emit(duration: 0.05)
        await settle()
        h.model.stop()
        #expect(h.model.startLatency != nil)

        await h.model.start()
        #expect(h.model.startLatency == nil)
    }
}

struct RecordingActivityStateTests {
    @Test func recordingStateCountsFromAStartDateBeforeNow() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let state = RecordingActivityAttributes.ContentState.recording(elapsed: 12, now: now)

        #expect(state.clockStart == now.addingTimeInterval(-12))
        #expect(!state.isPaused)
    }

    @Test func pausedStateHasNoStartDateAndKeepsTheElapsedTime() {
        let state = RecordingActivityAttributes.ContentState.paused(elapsed: 12)

        #expect(state.clockStart == nil)
        #expect(state.elapsed == 12)
        #expect(state.isPaused)
    }
}
