import Foundation
@testable import MURMUR

/// A recognizer that answers from a script, so the service can be tested without models or a microphone.
final class FakeSpeechEngine: SpeechEngine, @unchecked Sendable {
    struct State {
        var authorization: SpeechAuthorization = .authorized
        var authorizationAfterRequest: SpeechAuthorization = .authorized
        var locales: [Locale] = ["en-US", "es-ES"].map(Locale.init(identifier:))
        var result: Result<Transcript, any Error> = .success(
            Transcript(
                text: "Hello there",
                segments: [
                    TranscriptSegment(text: "Hello", start: 0.2, duration: 0.4),
                    TranscriptSegment(text: "there", start: 0.7, duration: 0.4),
                ],
                localeIdentifier: "en-US"
            )
        )
        var delay: Duration = .zero
        var requestCount = 0
        var transcribedURLs: [URL] = []
        var transcribedLocales: [Locale] = []
        var running = 0
        var maxRunning = 0
    }

    private let lock = NSLock()
    private var state = State()

    func configure(_ change: (inout State) -> Void) {
        lock.lock(); defer { lock.unlock() }
        change(&state)
    }

    func read<T>(_ value: (State) -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return value(state)
    }

    var authorization: SpeechAuthorization { read(\.authorization) }

    func requestAuthorization() async -> SpeechAuthorization {
        configure {
            $0.requestCount += 1
            $0.authorization = $0.authorizationAfterRequest
        }
        return authorization
    }

    func supportedLocales() async -> [Locale] { read(\.locales) }

    func transcribe(audioURL: URL, locale: Locale) async throws -> Transcript {
        configure {
            $0.transcribedURLs.append(audioURL)
            $0.transcribedLocales.append(locale)
            $0.running += 1
            $0.maxRunning = max($0.maxRunning, $0.running)
        }
        defer { configure { $0.running -= 1 } }
        let delay = read(\.delay)
        if delay > .zero { try await Task.sleep(for: delay) }
        return try read(\.result).get()
    }
}
