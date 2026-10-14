import Foundation
import SwiftData

/// Every change to a recording's transcript goes through here, so a failed save never leaves a
/// half-updated note on screen.
extension RecordingRepository {
    func recording(withID id: UUID) -> Recording? {
        var descriptor = FetchDescriptor<Recording>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Notes whose transcription was queued but never finished (the app was closed first).
    func pendingTranscriptions() -> [Recording] {
        let pending = TranscriptionStatus.pending.rawValue
        let descriptor = FetchDescriptor<Recording>(
            predicate: #Predicate { $0.transcriptionStatusRaw == pending },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func markTranscriptionPending(_ recording: Recording) throws {
        try commit {
            recording.transcriptionStatus = .pending
            recording.transcriptionFailure = nil
        }
    }

    func markTranscriptionFailed(_ recording: Recording, _ failure: TranscriptionFailure) throws {
        try commit {
            recording.transcriptionStatus = .failed
            recording.transcriptionFailure = failure
        }
    }

    /// Stores a fresh recognition result, replacing any earlier text and manual edits.
    func apply(_ transcript: Transcript, to recording: Recording) throws {
        try commit {
            recording.transcriptText = transcript.text
            recording.transcriptOriginalText = transcript.text
            recording.transcriptSegments = transcript.segments
            recording.transcriptLocaleIdentifier = transcript.localeIdentifier
            recording.isTranscriptEdited = false
            recording.transcriptionStatus = .completed
            recording.transcriptionFailure = nil
        }
    }

    /// Saves the user's own version of the text. The word timings are kept as they were.
    func updateTranscript(_ recording: Recording, text: String) throws {
        try commit {
            recording.transcriptText = text
            recording.isTranscriptEdited = text != (recording.transcriptOriginalText ?? "")
        }
    }

    func restoreOriginalTranscript(_ recording: Recording) throws {
        try commit {
            recording.transcriptText = recording.transcriptOriginalText
            recording.isTranscriptEdited = false
        }
    }

    /// Applies a change and saves; if saving fails the change is rolled back and the error thrown.
    func commit(_ change: () -> Void) throws {
        change()
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
