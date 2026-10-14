import Foundation
import SwiftData
import Testing
@testable import MURMUR

@MainActor
struct TranscriptionServiceTests {
    @MainActor private struct Fixture {
        let store = TestStore()
        let container: ModelContainer
        let repository: RecordingRepository
        let engine = FakeSpeechEngine()
        let settings: TranscriptionSettings
        let service: TranscriptionService

        init() throws {
            container = try PersistenceController.makeContainer(inMemory: true)
            repository = RecordingRepository(context: container.mainContext, fileStore: store.fileStore)
            let name = "MURMURTests-\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: name)!
            defaults.removePersistentDomain(forName: name)
            settings = TranscriptionSettings(defaults: defaults)
            service = TranscriptionService(engine: engine, repository: repository, settings: settings)
        }

        func saveRecording(title: String = "Note") throws -> Recording {
            try repository.save(temporaryURL: store.writeTemporaryFile(), duration: 5, waveform: [0.2], title: title)
        }

        func cleanUp() { store.cleanUp() }
    }

    @Test func aSavedRecordingIsTranscribedAndStored() async throws {
        let f = try Fixture(); defer { f.cleanUp() }
        let recording = try f.saveRecording()

        f.service.transcribeAfterSave(recording)
        #expect(recording.transcriptionStatus == .pending)
        #expect(f.service.isBusy(recording))
        await f.service.waitUntilIdle()

        #expect(recording.transcriptionStatus == .completed)
        #expect(recording.transcriptText == "Hello there")
        #expect(recording.transcriptOriginalText == "Hello there")
        #expect(recording.transcriptSegments.count == 2)
        #expect(recording.transcriptLocaleIdentifier == "en-US")
        #expect(!recording.isTranscriptEdited)
        #expect(!f.service.isBusy(recording))
        #expect(f.engine.read(\.transcribedURLs) == [recording.fileURL(in: f.store.fileStore)])
    }

    @Test func switchingAutoTranscribeOffLeavesTheNoteUntouched() async throws {
        let f = try Fixture(); defer { f.cleanUp() }
        f.settings.autoTranscribe = false
        let recording = try f.saveRecording()

        f.service.transcribeAfterSave(recording)
        await f.service.waitUntilIdle()

        #expect(recording.transcriptionStatus == .notRequested)
        #expect(f.engine.read(\.transcribedURLs).isEmpty)

        // The manual action still works.
        f.service.transcribe(recording)
        await f.service.waitUntilIdle()
        #expect(recording.transcriptionStatus == .completed)
    }

    @Test func aDeniedPermissionFailsWithoutCallingTheRecognizer() async throws {
        let f = try Fixture(); defer { f.cleanUp() }
        f.engine.configure { $0.authorization = .denied }
        let recording = try f.saveRecording()

        f.service.transcribe(recording)
        await f.service.waitUntilIdle()

        #expect(recording.transcriptionStatus == .failed)
        #expect(recording.transcriptionFailure == .notAuthorized)
        #expect(f.engine.read(\.transcribedURLs).isEmpty)
        #expect(f.engine.read(\.requestCount) == 0)
    }

    @Test func theFirstRunAsksForPermissionAndThenTranscribes() async throws {
        let f = try Fixture(); defer { f.cleanUp() }
        f.engine.configure { $0.authorization = .notDetermined }
        let recording = try f.saveRecording()

        f.service.transcribe(recording)
        await f.service.waitUntilIdle()

        #expect(f.engine.read(\.requestCount) == 1)
        #expect(recording.transcriptionStatus == .completed)
    }

    @Test func refusingThePromptFailsAsNotAuthorized() async throws {
        let f = try Fixture(); defer { f.cleanUp() }
        f.engine.configure {
            $0.authorization = .notDetermined
            $0.authorizationAfterRequest = .denied
        }
        let recording = try f.saveRecording()

        f.service.transcribe(recording)
        await f.service.waitUntilIdle()

        #expect(recording.transcriptionFailure == .notAuthorized)
    }

    @Test func theChosenLanguageIsTheOneUsed() async throws {
        let f = try Fixture(); defer { f.cleanUp() }
        f.settings.languageIdentifier = "es-ES"
        let recording = try f.saveRecording()

        f.service.transcribe(recording)
        await f.service.waitUntilIdle()

        #expect(f.engine.read(\.transcribedLocales).map { $0.identifier(.bcp47) } == ["es-ES"])
    }

    @Test func aLanguageNoOneCanDoFailsAsUnsupported() async throws {
        let f = try Fixture(); defer { f.cleanUp() }
        f.settings.languageIdentifier = "ja-JP"
        let recording = try f.saveRecording()

        f.service.transcribe(recording)
        await f.service.waitUntilIdle()

        #expect(recording.transcriptionFailure == .languageUnsupported)
        #expect(f.engine.read(\.transcribedURLs).isEmpty)
    }

    @Test func recognizerErrorsAreRecordedWithTheirReason() async throws {
        let f = try Fixture(); defer { f.cleanUp() }
        let cases: [(any Error, TranscriptionFailure)] = [
            (TranscriptionError.noSpeech, .noSpeech),
            (TranscriptionError.onDeviceUnavailable, .onDeviceUnavailable),
            (TranscriptionError.failed("boom"), .failed),
            (URLError(.badURL), .failed),
        ]
        for (error, expected) in cases {
            f.engine.configure { $0.result = .failure(error) }
            let recording = try f.saveRecording()
            f.service.transcribe(recording)
            await f.service.waitUntilIdle()
            #expect(recording.transcriptionStatus == .failed)
            #expect(recording.transcriptionFailure == expected)
            #expect(!recording.hasTranscript)
        }
    }

    @Test func aRetryAfterAFailureClearsTheError() async throws {
        let f = try Fixture(); defer { f.cleanUp() }
        f.engine.configure { $0.result = .failure(TranscriptionError.failed("boom")) }
        let recording = try f.saveRecording()
        f.service.transcribe(recording)
        await f.service.waitUntilIdle()
        #expect(recording.transcriptionStatus == .failed)

        f.engine.configure {
            $0.result = .success(Transcript(text: "Second try", segments: [], localeIdentifier: "en-US"))
        }
        f.service.transcribe(recording)
        await f.service.waitUntilIdle()

        #expect(recording.transcriptionStatus == .completed)
        #expect(recording.transcriptionFailure == nil)
        #expect(recording.transcriptText == "Second try")
    }

    @Test func recordingsAreTranscribedOneAtATime() async throws {
        let f = try Fixture(); defer { f.cleanUp() }
        f.engine.configure { $0.delay = .milliseconds(40) }
        let notes = try (0..<3).map { try f.saveRecording(title: "Note \($0)") }

        notes.forEach { f.service.transcribe($0) }
        await f.service.waitUntilIdle()

        #expect(f.engine.read(\.maxRunning) == 1)
        #expect(notes.allSatisfy { $0.transcriptionStatus == .completed })
        #expect(f.engine.read(\.transcribedURLs).count == 3)
    }

    @Test func askingTwiceForTheSameNoteDoesNotRunItTwice() async throws {
        let f = try Fixture(); defer { f.cleanUp() }
        f.engine.configure { $0.delay = .milliseconds(30) }
        let recording = try f.saveRecording()

        f.service.transcribe(recording)
        f.service.transcribe(recording)
        await f.service.waitUntilIdle()

        #expect(f.engine.read(\.transcribedURLs).count == 1)
    }

    @Test func aNoteDeletedWhileWaitingIsSkipped() async throws {
        let f = try Fixture(); defer { f.cleanUp() }
        f.engine.configure { $0.delay = .milliseconds(40) }
        let first = try f.saveRecording(title: "First")
        let second = try f.saveRecording(title: "Second")

        f.service.transcribe(first)
        f.service.transcribe(second)
        try f.repository.delete(second)
        await f.service.waitUntilIdle()

        #expect(first.transcriptionStatus == .completed)
        #expect(f.engine.read(\.transcribedURLs).count == 1)
    }

    @Test func pendingNotesAreResumedAfterARelaunch() async throws {
        let f = try Fixture(); defer { f.cleanUp() }
        let recording = try f.saveRecording()
        try f.repository.markTranscriptionPending(recording) // what a killed app leaves behind
        let done = try f.saveRecording(title: "Done")
        try f.repository.apply(Transcript(text: "Already", segments: [], localeIdentifier: "en-US"), to: done)

        f.service.resumePending()
        await f.service.waitUntilIdle()

        #expect(recording.transcriptionStatus == .completed)
        #expect(f.engine.read(\.transcribedURLs).count == 1)
        #expect(done.transcriptText == "Already")
    }

    @Test func cancellationLeavesTheNotePendingForTheNextLaunch() async throws {
        let f = try Fixture(); defer { f.cleanUp() }
        f.engine.configure { $0.result = .failure(CancellationError()) }
        let recording = try f.saveRecording()

        f.service.transcribe(recording)
        await f.service.waitUntilIdle()

        #expect(recording.transcriptionStatus == .pending)
        #expect(f.repository.pendingTranscriptions().map(\.id) == [recording.id])
    }

    @Test func transcribingAgainReplacesTheTextAndDropsManualEdits() async throws {
        let f = try Fixture(); defer { f.cleanUp() }
        let recording = try f.saveRecording()
        f.service.transcribe(recording)
        await f.service.waitUntilIdle()
        try f.repository.updateTranscript(recording, text: "My own words")
        #expect(recording.isTranscriptEdited)

        f.service.transcribe(recording)
        await f.service.waitUntilIdle()

        #expect(recording.transcriptText == "Hello there")
        #expect(!recording.isTranscriptEdited)
    }
}
