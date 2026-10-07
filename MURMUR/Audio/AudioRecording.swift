import Foundation

/// One measurement emitted while recording.
struct RecorderSample: Sendable, Equatable {
    /// Normalized signal level in `0...1` (0 = silence).
    let level: Float
    /// Audio written to the file so far, in seconds. Excludes paused time.
    let duration: TimeInterval
}

/// A finished capture that still lives in the temporary directory.
///
/// It has not been persisted yet: turning it into a library entry is the persistence layer's job.
struct RecordedAudio: Sendable, Equatable {
    let fileURL: URL
    let duration: TimeInterval
    /// Peak envelope of the whole recording, bounded in size regardless of its length.
    let waveform: [Float]
}

/// Boundary around audio capture (`AVAudioEngine`).
///
/// The recorder owns the engine and the temporary file. It does not know about SwiftData, the
/// library or SwiftUI: it produces `RecordedAudio` and a stream of `RecorderSample`.
@MainActor
protocol AudioRecording: AnyObject {
    /// Starts capturing into a temporary file.
    ///
    /// The stream yields about 20 samples per second and finishes when capture ends. It finishes
    /// with an error if capture fails (for example when the disk is full).
    func start() throws -> AsyncThrowingStream<RecorderSample, Error>

    func pause()
    func resume() throws

    /// Finalizes the temporary file and returns it.
    func stop() throws -> RecordedAudio

    /// Stops capturing and deletes the temporary file.
    func discard()
}
