import AVFoundation

enum AudioRecorderError: Error, Equatable, LocalizedError {
    case alreadyRecording
    case notRecording
    case invalidInputFormat
    case noAudioCaptured

    var errorDescription: String? {
        switch self {
        case .alreadyRecording: "A recording is already in progress."
        case .notRecording: "There is no recording in progress."
        case .invalidInputFormat: "The microphone is not available."
        case .noAudioCaptured: "No audio was captured."
        }
    }
}

/// Records microphone audio to an AAC `.m4a` file with `AVAudioEngine`.
///
/// The session must already be active for recording (see `AudioSessionControlling`).
@MainActor
final class AudioRecorder: AudioRecording {
    private let makeTemporaryURL: () -> URL
    private let removeFile: (URL) -> Void

    private var engine: AVAudioEngine?
    private var processor: RecordingTapProcessor?
    private var fileURL: URL?

    init(makeTemporaryURL: @escaping () -> URL, removeFile: @escaping (URL) -> Void) {
        self.makeTemporaryURL = makeTemporaryURL
        self.removeFile = removeFile
    }

    var isActive: Bool { engine != nil }

    func start() throws -> AsyncThrowingStream<RecorderSample, Error> {
        guard engine == nil else { throw AudioRecorderError.alreadyRecording }

        let engine = AVAudioEngine()
        let format = engine.inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw AudioRecorderError.invalidInputFormat
        }

        let url = makeTemporaryURL()
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVEncoderBitRateKey: 64_000 * Int(format.channelCount),
        ]
        let file = try AVAudioFile(
            forWriting: url,
            settings: settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )

        // Newest wins: a slow consumer drops old meter samples instead of growing memory.
        let (stream, continuation) = AsyncThrowingStream<RecorderSample, Error>.makeStream(
            bufferingPolicy: .bufferingNewest(32)
        )
        let processor = RecordingTapProcessor(file: file, sampleRate: format.sampleRate, continuation: continuation)
        Self.installTap(on: engine, format: format, processor: processor)

        do {
            engine.prepare()
            try engine.start()
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            _ = processor.finish()
            removeFile(url)
            throw error
        }

        self.engine = engine
        self.processor = processor
        self.fileURL = url
        return stream
    }

    func pause() {
        guard let engine, let processor else { return }
        processor.setPaused(true)
        engine.pause() // releases the microphone while paused
    }

    func resume() throws {
        guard let engine, let processor else { throw AudioRecorderError.notRecording }
        try engine.start()
        processor.setPaused(false)
    }

    func stop() throws -> RecordedAudio {
        guard let engine, let processor, let url = fileURL else { throw AudioRecorderError.notRecording }
        tearDown(engine: engine)

        let frames = processor.finish()
        let sampleRate = processor.sampleRate
        reset()

        guard frames > 0 else {
            removeFile(url)
            throw AudioRecorderError.noAudioCaptured
        }
        return RecordedAudio(fileURL: url, duration: Double(frames) / sampleRate, waveform: [])
    }

    func discard() {
        guard let engine, let processor, let url = fileURL else { return }
        tearDown(engine: engine)
        _ = processor.finish()
        reset()
        removeFile(url)
    }

    // MARK: - Private

    private func tearDown(engine: AVAudioEngine) {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    private func reset() {
        engine = nil
        processor = nil
        fileURL = nil
    }

    /// `nonisolated` so the tap closure is not inferred as main-actor isolated.
    private nonisolated static func installTap(
        on engine: AVAudioEngine,
        format: AVAudioFormat,
        processor: RecordingTapProcessor
    ) {
        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            processor.process(buffer)
        }
    }
}
