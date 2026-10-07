import AVFoundation
import os

/// Receives buffers on the audio thread, writes them to disk and emits level samples.
///
/// Deliberately not `@MainActor`: `AVAudioEngine` calls the tap from a real-time thread, and a
/// closure created in a main-actor context would trip Swift 6 isolation checks there. All mutable
/// state lives behind a lock so the main actor can pause or finish while buffers keep arriving.
final class RecordingTapProcessor: @unchecked Sendable {
    /// Meter window: the peak of the buffers inside it becomes one sample (~20 Hz).
    static let sampleWindow: TimeInterval = 0.05
    /// Resolution of the summary saved with a recording (it holds up to twice this many bins).
    static let waveformBinCount = 100

    private struct State {
        var file: AVAudioFile?
        var isPaused = false
        var framesWritten: AVAudioFramePosition = 0
        var windowFrames: AVAudioFrameCount = 0
        var windowPeakRMS: Float = 0
        var failure: (any Error)?
        var waveform = WaveformDownsampler(binCount: RecordingTapProcessor.waveformBinCount)
    }

    let sampleRate: Double
    private let lock: OSAllocatedUnfairLock<State>
    private let continuation: AsyncThrowingStream<RecorderSample, Error>.Continuation

    init(
        file: AVAudioFile,
        sampleRate: Double,
        continuation: AsyncThrowingStream<RecorderSample, Error>.Continuation
    ) {
        self.sampleRate = sampleRate
        self.continuation = continuation
        self.lock = OSAllocatedUnfairLock(initialState: State(file: file))
    }

    /// Called for every captured buffer.
    func process(_ buffer: AVAudioPCMBuffer) {
        let outcome: Result<RecorderSample?, any Error>? = lock.withLockUnchecked { state in
            guard let file = state.file, !state.isPaused, state.failure == nil else { return nil }
            do {
                try file.write(from: buffer)
            } catch {
                state.failure = error
                return .failure(error)
            }
            state.framesWritten += AVAudioFramePosition(buffer.frameLength)
            state.windowFrames += buffer.frameLength
            state.windowPeakRMS = max(state.windowPeakRMS, LevelMeter.rms(of: buffer))

            let windowFrames = AVAudioFrameCount(sampleRate * Self.sampleWindow)
            guard state.windowFrames >= windowFrames else { return .success(nil) }
            let sample = RecorderSample(
                level: LevelMeter.normalizedLevel(fromRMS: state.windowPeakRMS),
                duration: Double(state.framesWritten) / sampleRate
            )
            // Carry the remainder over so the average rate stays ~20 Hz whatever the buffer size.
            state.windowFrames -= windowFrames
            state.windowPeakRMS = 0
            state.waveform.append(sample.level)
            return .success(sample)
        }

        switch outcome {
        case .success(let sample?): continuation.yield(sample)
        case .failure(let error): continuation.finish(throwing: error)
        case .success(nil), nil: break
        }
    }

    func setPaused(_ paused: Bool) {
        lock.withLock { $0.isPaused = paused }
    }

    /// Closes the file and ends the sample stream. Returns the frames written.
    func finish() -> AVAudioFramePosition {
        let frames = lock.withLock { state -> AVAudioFramePosition in
            state.file = nil // AVAudioFile finalizes the container when released.
            return state.framesWritten
        }
        continuation.finish()
        return frames
    }

    /// Bounded summary of everything captured so far, for saving with the recording.
    var waveform: [Float] {
        lock.withLock { $0.waveform.result }
    }

    var framesWritten: AVAudioFramePosition {
        lock.withLock { $0.framesWritten }
    }
}
