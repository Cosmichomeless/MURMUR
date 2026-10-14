import AVFoundation
import Speech

/// Transcribes with Apple's Speech framework, always on the device.
///
/// - iOS 26 and later: `SpeechAnalyzer` / `SpeechTranscriber`, which run the system's on-device
///   model (downloaded once per language by the system, never the audio).
/// - Earlier versions, or a language the new API does not offer: `SFSpeechRecognizer` with
///   `requiresOnDeviceRecognition`, which refuses to fall back to Apple's servers.
struct AppleSpeechEngine: SpeechEngine {
    var authorization: SpeechAuthorization {
        Self.map(SFSpeechRecognizer.authorizationStatus())
    }

    func requestAuthorization() async -> SpeechAuthorization {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: Self.map(status))
            }
        }
    }

    func supportedLocales() async -> [Locale] {
        var locales = Array(SFSpeechRecognizer.supportedLocales()).filter {
            SFSpeechRecognizer(locale: $0)?.supportsOnDeviceRecognition == true
        }
        if #available(iOS 26, *), SpeechTranscriber.isAvailable {
            locales += await SpeechTranscriber.supportedLocales
        }
        var seen = Set<String>()
        return locales
            .filter { seen.insert($0.identifier(.bcp47)).inserted }
            .sorted { $0.identifier(.bcp47) < $1.identifier(.bcp47) }
    }

    func transcribe(audioURL: URL, locale: Locale) async throws -> Transcript {
        guard authorization == .authorized else { throw TranscriptionError.notAuthorized }
        if #available(iOS 26, *), SpeechTranscriber.isAvailable,
           let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) {
            do {
                return try await transcribeWithAnalyzer(audioURL: audioURL, locale: supported)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // The language assets may be unavailable (offline first use): try the older
                // recognizer if it can do this language on the device, otherwise report the error.
                guard Self.legacySupportsOnDevice(locale) else { throw Self.map(error) }
            }
        }
        return try await transcribeWithRecognizer(audioURL: audioURL, locale: locale)
    }

    // MARK: - SpeechAnalyzer (iOS 26+)

    @available(iOS 26, *)
    private func transcribeWithAnalyzer(audioURL: URL, locale: Locale) async throws -> Transcript {
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: [.audioTimeRange]
        )
        if let installation = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await installation.downloadAndInstall()
        }
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let file = try AVAudioFile(forReading: audioURL)

        let collector = Task { () -> [SpeechTranscriber.Result] in
            var results: [SpeechTranscriber.Result] = []
            for try await result in transcriber.results { results.append(result) }
            return results
        }
        do {
            if let last = try await analyzer.analyzeSequence(from: file) {
                try await analyzer.finalizeAndFinish(through: last)
            } else {
                await analyzer.cancelAndFinishNow()
            }
        } catch {
            collector.cancel()
            throw error
        }
        let results = try await collector.value

        var text = ""
        var segments: [TranscriptSegment] = []
        for result in results {
            text += String(result.text.characters)
            for run in result.text.runs {
                let word = String(result.text[run.range].characters).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !word.isEmpty, let range = run.audioTimeRange else { continue }
                segments.append(TranscriptSegment(text: word, start: range.start.seconds, duration: range.duration.seconds))
            }
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranscriptionError.noSpeech }
        return Transcript(text: text, segments: segments, localeIdentifier: locale.identifier(.bcp47))
    }

    // MARK: - SFSpeechRecognizer

    private static func legacySupportsOnDevice(_ locale: Locale) -> Bool {
        SFSpeechRecognizer(locale: locale)?.supportsOnDeviceRecognition == true
    }

    private func transcribeWithRecognizer(audioURL: URL, locale: Locale) async throws -> Transcript {
        guard let recognizer = SFSpeechRecognizer(locale: locale) else { throw TranscriptionError.languageUnsupported }
        // Without this the request could be sent to Apple's servers: never allowed here.
        guard recognizer.supportsOnDeviceRecognition else { throw TranscriptionError.onDeviceUnavailable }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        request.addsPunctuation = true

        let task = RecognitionTaskBox()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let once = ResumeOnce(continuation)
                task.set(recognizer.recognitionTask(with: request) { result, error in
                    if let result, result.isFinal {
                        let text = result.bestTranscription.formattedString
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if text.isEmpty {
                            once.resume(throwing: TranscriptionError.noSpeech)
                        } else {
                            let segments = result.bestTranscription.segments.map {
                                TranscriptSegment(text: $0.substring, start: $0.timestamp, duration: $0.duration)
                            }
                            once.resume(returning: Transcript(
                                text: text,
                                segments: segments,
                                localeIdentifier: locale.identifier(.bcp47)
                            ))
                        }
                    } else if let error {
                        once.resume(throwing: task.wasCancelled ? CancellationError() : Self.map(error))
                    }
                })
            }
        } onCancel: {
            task.cancel()
        }
    }

    // MARK: - Mapping

    private static func map(_ status: SFSpeechRecognizerAuthorizationStatus) -> SpeechAuthorization {
        switch status {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .denied
        }
    }

    static func map(_ error: any Error) -> TranscriptionError {
        if let error = error as? TranscriptionError { return error }
        let nsError = error as NSError
        // "No speech detected" comes back as an Assistant error rather than an empty result.
        if nsError.domain == "kAFAssistantErrorDomain", nsError.code == 1110 { return .noSpeech }
        return .failed(error.localizedDescription)
    }
}

/// Lets a cancelled Swift task cancel the recognizer's task, which is created after the handler.
private final class RecognitionTaskBox: @unchecked Sendable {
    private let lock = NSLock()
    private var task: SFSpeechRecognitionTask?
    private var isCancelled = false

    func set(_ task: SFSpeechRecognitionTask) {
        lock.lock(); defer { lock.unlock() }
        self.task = task
        if isCancelled { task.cancel() }
    }

    var wasCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return isCancelled
    }

    func cancel() {
        lock.lock(); defer { lock.unlock() }
        isCancelled = true
        task?.cancel()
    }
}

/// The recognizer can call back several times (a result, then an error); a continuation may only resume once.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Transcript, any Error>?

    init(_ continuation: CheckedContinuation<Transcript, any Error>) {
        self.continuation = continuation
    }

    func resume(returning value: Transcript) {
        take()?.resume(returning: value)
    }

    func resume(throwing error: any Error) {
        take()?.resume(throwing: error)
    }

    private func take() -> CheckedContinuation<Transcript, any Error>? {
        lock.lock(); defer { lock.unlock() }
        defer { continuation = nil }
        return continuation
    }
}
