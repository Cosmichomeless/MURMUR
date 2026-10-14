import Foundation
import SwiftData

/// Makes the model usable with CloudKit: no `unique` constraint and a default for every property.
///
/// CloudKit cannot enforce uniqueness and needs to create a record before it has every value, so
/// both are required whether or not the user ever turns sync on. The migration from
/// `MurmurSchemaV3` is lightweight and keeps every note. `id` stays the identity of a note; since
/// the store no longer rejects a second note with the same `id`, `RecordingReconciler` removes such
/// duplicates.
enum MurmurSchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] { [Recording.self] }

    /// Metadata of one saved voice note. The audio itself lives in a file managed by
    /// `RecordingFileStore`; this model only stores its *name*.
    ///
    /// The file is referenced by name rather than by absolute URL because the app container path
    /// changes between installs, updates and simulators. `fileURL(in:)` resolves the current location.
    @Model
    final class Recording {
        var id: UUID = UUID()
        var title: String = ""
        /// File name inside `RecordingFileStore.recordingsDirectory`, e.g. `3F2A….m4a`.
        var fileName: String = ""
        var duration: TimeInterval = 0
        var createdAt: Date = Date.now
        /// Encoded peak envelope (see `WaveformCodec`). Bounded in size.
        var waveformData: Data = Data()

        /// The text shown, searched and exported. Equal to the recognizer's output until the user edits it.
        var transcriptText: String?
        /// The recognizer's output as it came, kept so a manual edit can be undone.
        var transcriptOriginalText: String?
        /// Encoded `[TranscriptSegment]` (see `TranscriptSegmentCodec`): the recognizer's word timings.
        var transcriptSegmentsData: Data?
        /// Identifier of the language the transcription was made in, e.g. `es-ES`.
        var transcriptLocaleIdentifier: String?
        /// `true` once the user changed `transcriptText`; the word timings may no longer line up with it.
        var isTranscriptEdited: Bool = false
        /// Raw `TranscriptionStatus`. Stored as a string so the schema stays stable if cases are added.
        var transcriptionStatusRaw: String = TranscriptionStatus.notRequested.rawValue
        /// Raw `TranscriptionFailure` of the last failed attempt.
        var transcriptionFailureRaw: String?

        /// The note's tags, one per line (see `TagList`). A plain string keeps the migration trivial.
        var tagsRaw: String = ""

        init(
            id: UUID = UUID(),
            title: String,
            fileName: String,
            duration: TimeInterval,
            createdAt: Date = .now,
            waveform: [Float] = []
        ) {
            self.id = id
            self.title = title
            self.fileName = fileName
            self.duration = duration
            self.createdAt = createdAt
            self.waveformData = WaveformCodec.encode(waveform)
        }
    }
}
