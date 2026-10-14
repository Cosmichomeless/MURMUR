import Foundation

enum SpeechAuthorization: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

/// The speech recognizer, behind a seam so everything around it can be tested without audio models.
///
/// The real one is `AppleSpeechEngine`; tests use a fake that returns canned transcripts.
protocol SpeechEngine: Sendable {
    var authorization: SpeechAuthorization { get }

    /// Shows the system prompt the first time; later calls just report the answer.
    func requestAuthorization() async -> SpeechAuthorization

    /// Languages that can be transcribed on this device, without sending audio anywhere.
    func supportedLocales() async -> [Locale]

    /// Transcribes a whole file. Audio never leaves the device.
    ///
    /// - Throws: `TranscriptionError`, or `CancellationError` if the task is cancelled.
    func transcribe(audioURL: URL, locale: Locale) async throws -> Transcript
}
