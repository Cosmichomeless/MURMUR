import Foundation
import SwiftData
import Testing
@testable import MURMUR

@MainActor
struct TranscriptRepositoryTests {
    private func makeRepository(_ store: TestStore) throws -> (RecordingRepository, ModelContainer) {
        let container = try PersistenceController.makeContainer(inMemory: true)
        return (RecordingRepository(context: container.mainContext, fileStore: store.fileStore), container)
    }

    private let transcript = Transcript(
        text: "Buy milk and eggs",
        segments: [TranscriptSegment(text: "Buy", start: 0, duration: 0.3)],
        localeIdentifier: "en-US"
    )

    @Test func editingMarksTheNoteAndRestoringUndoesIt() throws {
        let store = TestStore(); defer { store.cleanUp() }
        let (repository, container) = try makeRepository(store)
        defer { withExtendedLifetime(container) {} }
        let recording = try repository.save(temporaryURL: store.writeTemporaryFile(), duration: 3, waveform: [])
        try repository.apply(transcript, to: recording)

        try repository.updateTranscript(recording, text: "Buy oat milk")
        #expect(recording.transcriptText == "Buy oat milk")
        #expect(recording.transcriptOriginalText == "Buy milk and eggs")
        #expect(recording.isTranscriptEdited)
        #expect(recording.transcriptSegments.count == 1) // timings are kept

        try repository.restoreOriginalTranscript(recording)
        #expect(recording.transcriptText == "Buy milk and eggs")
        #expect(!recording.isTranscriptEdited)
    }

    @Test func typingTheOriginalTextBackIsNotAnEdit() throws {
        let store = TestStore(); defer { store.cleanUp() }
        let (repository, container) = try makeRepository(store)
        defer { withExtendedLifetime(container) {} }
        let recording = try repository.save(temporaryURL: store.writeTemporaryFile(), duration: 3, waveform: [])
        try repository.apply(transcript, to: recording)

        try repository.updateTranscript(recording, text: "changed")
        try repository.updateTranscript(recording, text: "Buy milk and eggs")

        #expect(!recording.isTranscriptEdited)
    }

    @Test func aTranscriptSurvivesReopeningTheStore() throws {
        let store = TestStore(); defer { store.cleanUp() }
        let url = store.root.appendingPathComponent("store.sqlite")
        var id: UUID
        do {
            let container = try PersistenceController.makeContainer(storeURL: url)
            let repository = RecordingRepository(context: container.mainContext, fileStore: store.fileStore)
            let recording = try repository.save(temporaryURL: store.writeTemporaryFile(), duration: 3, waveform: [])
            try repository.apply(transcript, to: recording)
            id = recording.id
        }

        let reopened = try PersistenceController.makeContainer(storeURL: url)
        let repository = RecordingRepository(context: reopened.mainContext, fileStore: store.fileStore)
        let recording = try #require(repository.recording(withID: id))
        #expect(recording.transcriptText == "Buy milk and eggs")
        #expect(recording.transcriptionStatus == .completed)
        #expect(recording.transcriptSegments == transcript.segments)
        #expect(recording.hasTranscript)
    }

    @Test func aBlankTranscriptCountsAsNone() {
        let recording = Recording(title: "x", fileName: "x.m4a", duration: 1)
        #expect(!recording.hasTranscript)
        recording.transcriptText = "  \n "
        #expect(!recording.hasTranscript)
        recording.transcriptText = "hi"
        #expect(recording.hasTranscript)
    }
}
