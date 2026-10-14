import Foundation

extension Recording {
    var transcriptionStatus: TranscriptionStatus {
        get { TranscriptionStatus(rawValue: transcriptionStatusRaw) ?? .notRequested }
        set { transcriptionStatusRaw = newValue.rawValue }
    }

    var transcriptionFailure: TranscriptionFailure? {
        get { transcriptionFailureRaw.flatMap(TranscriptionFailure.init(rawValue:)) }
        set { transcriptionFailureRaw = newValue?.rawValue }
    }

    var transcriptSegments: [TranscriptSegment] {
        get { TranscriptSegmentCodec.decode(transcriptSegmentsData) }
        set { transcriptSegmentsData = TranscriptSegmentCodec.encode(newValue) }
    }

    /// `true` when there is text to show, search and export.
    var hasTranscript: Bool {
        !(transcriptText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
