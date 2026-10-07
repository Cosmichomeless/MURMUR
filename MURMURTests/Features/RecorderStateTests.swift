import Testing
@testable import MURMUR

struct RecorderStateTests {
    @Test func happyPathThroughPauseAndStop() {
        var state = RecorderState.idle
        for (event, expected) in [
            (RecorderState.Event.start, RecorderState.recording),
            (.pause, .paused),
            (.resume, .recording),
            (.stop, .idle),
        ] {
            state = try! #require(state.applying(event))
            #expect(state == expected)
        }
    }

    @Test func discardIsValidWhileRecordingAndPaused() {
        #expect(RecorderState.recording.applying(.discard) == .idle)
        #expect(RecorderState.paused.applying(.discard) == .idle)
    }

    @Test func invalidTransitionsAreRejected() {
        #expect(RecorderState.idle.applying(.stop) == nil)
        #expect(RecorderState.idle.applying(.pause) == nil)
        #expect(RecorderState.idle.applying(.discard) == nil)
        #expect(RecorderState.recording.applying(.start) == nil)
        #expect(RecorderState.recording.applying(.resume) == nil)
        #expect(RecorderState.paused.applying(.pause) == nil)
    }

    @Test func failureCanBeDismissedOrRetried() {
        let failed = RecorderState.recording.applying(.fail("disk full"))
        #expect(failed == .failed("disk full"))
        #expect(failed?.applying(.dismissFailure) == .idle)
        #expect(failed?.applying(.start) == .recording)
    }

    @Test func onlyRecordingAndPausedAreCapturing() {
        #expect(RecorderState.recording.isCapturing)
        #expect(RecorderState.paused.isCapturing)
        #expect(!RecorderState.idle.isCapturing)
        #expect(!RecorderState.failed("x").isCapturing)
    }
}
