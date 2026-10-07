import Foundation
@testable import MURMUR

@MainActor
final class FakeAudioRecorder: AudioRecording {
    var startError: (any Error)?
    var resumeError: (any Error)?
    var stopError: (any Error)?
    var recorded = RecordedAudio(fileURL: URL(fileURLWithPath: "/tmp/fake.m4a"), duration: 2, waveform: [])

    private(set) var startCount = 0
    private(set) var pauseCount = 0
    private(set) var resumeCount = 0
    private(set) var stopCount = 0
    private(set) var discardCount = 0
    private var continuation: AsyncThrowingStream<RecorderSample, Error>.Continuation?

    func start() throws -> AsyncThrowingStream<RecorderSample, Error> {
        if let startError { throw startError }
        startCount += 1
        // Same policy as the real recorder: a slow consumer drops old samples instead of growing.
        let (stream, continuation) = AsyncThrowingStream<RecorderSample, Error>.makeStream(
            bufferingPolicy: .bufferingNewest(32)
        )
        self.continuation = continuation
        return stream
    }

    func pause() { pauseCount += 1 }

    func resume() throws {
        if let resumeError { throw resumeError }
        resumeCount += 1
    }

    func stop() throws -> RecordedAudio {
        stopCount += 1
        continuation?.finish()
        if let stopError { throw stopError }
        return recorded
    }

    func discard() {
        discardCount += 1
        continuation?.finish()
    }

    // Test controls

    func emit(duration: TimeInterval, level: Float = 0.5) {
        continuation?.yield(RecorderSample(level: level, duration: duration))
    }

    func failStream(with error: any Error) {
        continuation?.finish(throwing: error)
    }
}
