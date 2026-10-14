import Foundation
import Observation

/// Transcribes recordings one at a time, in the background of the UI, and keeps the result in the store.
///
/// The state that matters survives a relaunch: a note is marked `pending` before work starts, and
/// `resumePending()` picks up whatever a closed app left behind.
@MainActor
@Observable
final class TranscriptionService {
    /// The recording being transcribed right now, for progress indicators.
    private(set) var activeRecordingID: UUID?
    /// Languages the device can transcribe, loaded on demand for the settings screen.
    private(set) var availableLocales: [Locale] = []

    @ObservationIgnored let settings: TranscriptionSettings
    @ObservationIgnored private let engine: any SpeechEngine
    @ObservationIgnored private let repository: RecordingRepository
    @ObservationIgnored private var queue: [UUID] = []
    @ObservationIgnored private var worker: Task<Void, Never>?

    init(engine: any SpeechEngine, repository: RecordingRepository, settings: TranscriptionSettings) {
        self.engine = engine
        self.repository = repository
        self.settings = settings
    }

    var authorization: SpeechAuthorization { engine.authorization }

    /// `true` while the recording is waiting for its turn or being transcribed.
    func isBusy(_ recording: Recording) -> Bool {
        activeRecordingID == recording.id || queue.contains(recording.id)
    }

    /// Called right after a recording is saved. Does nothing if automatic transcription is off.
    func transcribeAfterSave(_ recording: Recording) {
        guard settings.autoTranscribe else { return }
        transcribe(recording)
    }

    /// Queues a recording, whatever its state (also used to retry or to redo with another language).
    func transcribe(_ recording: Recording) {
        guard !isBusy(recording) else { return }
        do {
            try repository.markTranscriptionPending(recording)
        } catch {
            return
        }
        queue.append(recording.id)
        startWorkerIfNeeded()
    }

    /// Queues the notes an earlier run left unfinished. Call at launch and when the app returns to the foreground.
    func resumePending() {
        for recording in repository.pendingTranscriptions() where !isBusy(recording) {
            queue.append(recording.id)
        }
        startWorkerIfNeeded()
    }

    func loadAvailableLocales() async {
        availableLocales = await engine.supportedLocales()
    }

    /// Waits until the queue is empty. For tests.
    func waitUntilIdle() async {
        await worker?.value
    }

    // MARK: - Private

    private func startWorkerIfNeeded() {
        guard worker == nil, !queue.isEmpty else { return }
        worker = Task { [weak self] in
            while let self, let id = self.queue.first {
                self.queue.removeFirst()
                await self.process(id)
            }
            self?.worker = nil
        }
    }

    private func process(_ id: UUID) async {
        guard let recording = repository.recording(withID: id) else { return } // deleted while waiting
        activeRecordingID = id
        defer { activeRecordingID = nil }

        var authorization = engine.authorization
        if authorization == .notDetermined {
            authorization = await engine.requestAuthorization()
        }
        guard authorization == .authorized else {
            fail(recording, .notAuthorized)
            return
        }

        let locales = await engine.supportedLocales()
        guard let locale = settings.resolveLocale(supported: locales) else {
            fail(recording, .languageUnsupported)
            return
        }

        let url = recording.fileURL(in: repository.fileStore)
        do {
            let transcript = try await engine.transcribe(audioURL: url, locale: locale)
            // The note may have been deleted while the recognizer worked.
            guard let current = repository.recording(withID: id) else { return }
            try repository.apply(transcript, to: current)
        } catch is CancellationError {
            return // stays pending: the next launch tries again
        } catch let error as TranscriptionError {
            fail(recording, error.failure)
        } catch {
            fail(recording, .failed)
        }
    }

    private func fail(_ recording: Recording, _ failure: TranscriptionFailure) {
        guard let current = repository.recording(withID: recording.id) else { return }
        try? repository.markTranscriptionFailed(current, failure)
    }
}
