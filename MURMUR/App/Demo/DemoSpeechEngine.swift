#if DEBUG
import Foundation

/// A recognizer for demo runs: no models, no permission prompt, a fixed answer after a short wait.
/// Demo audio is synthetic noise, so a real recognizer would find no speech in it.
struct DemoSpeechEngine: SpeechEngine {
    var authorization: SpeechAuthorization { .authorized }

    func requestAuthorization() async -> SpeechAuthorization { .authorized }

    func supportedLocales() async -> [Locale] {
        ["en-US", "es-ES", "fr-FR", "de-DE", "it-IT", "pt-BR"].map(Locale.init(identifier:))
    }

    func transcribe(audioURL: URL, locale: Locale) async throws -> Transcript {
        try await Task.sleep(for: .milliseconds(1500))
        return DemoLibrary.transcript(
            words: "Remember to send the draft before Friday and book the table for Saturday night",
            localeIdentifier: locale.identifier
        )
    }
}
#endif
