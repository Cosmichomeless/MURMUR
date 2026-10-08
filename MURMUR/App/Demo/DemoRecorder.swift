#if DEBUG
import Foundation

/// Stands in for `AudioRecorder` in demo mode: it emits the same ~20 Hz samples from a synthetic
/// voice instead of the microphone, and writes a real `.m4a` on stop. Everything downstream (view
/// model, waveform, repository, player) is the production code.
@MainActor
final class DemoRecorder: AudioRecording {
    private let store: RecordingFileStore
    private let seed: UInt64

    private var levels: [Float] = []
    private var url: URL?
    private var isPaused = false
    private var ticker: Task<Void, Never>?
    private var continuation: AsyncThrowingStream<RecorderSample, Error>.Continuation?

    init(store: RecordingFileStore, seed: UInt64 = 7) {
        self.store = store
        self.seed = seed
    }

    func start() throws -> AsyncThrowingStream<RecorderSample, Error> {
        guard url == nil else { throw AudioRecorderError.alreadyRecording }
        try store.prepareDirectories()
        url = store.makeTemporaryURL()
        levels = []
        isPaused = false

        let (stream, continuation) = AsyncThrowingStream<RecorderSample, Error>.makeStream(
            bufferingPolicy: .bufferingNewest(32)
        )
        self.continuation = continuation
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(DemoAudio.window))
                guard !Task.isCancelled, let self else { return }
                self.emit()
            }
        }
        return stream
    }

    func pause() { isPaused = true }

    func resume() throws {
        guard url != nil else { throw AudioRecorderError.notRecording }
        isPaused = false
    }

    func stop() throws -> RecordedAudio {
        guard let url else { throw AudioRecorderError.notRecording }
        let captured = levels
        finishCapture()
        guard !captured.isEmpty else {
            store.removeTemporary(at: url)
            throw AudioRecorderError.noAudioCaptured
        }
        try DemoAudio.write(levels: captured, to: url)
        return RecordedAudio(
            fileURL: url,
            duration: Double(captured.count) * DemoAudio.window,
            waveform: DemoAudio.waveform(for: captured)
        )
    }

    func discard() {
        guard let url else { return }
        finishCapture()
        store.removeTemporary(at: url)
    }

    // MARK: - Private

    private func emit() {
        guard !isPaused else { return }
        levels.append(DemoSignal.level(at: levels.count, seed: seed))
        continuation?.yield(RecorderSample(
            level: levels[levels.count - 1],
            duration: Double(levels.count) * DemoAudio.window
        ))
    }

    private func finishCapture() {
        ticker?.cancel()
        ticker = nil
        continuation?.finish()
        continuation = nil
        url = nil
        levels = []
    }
}
#endif
