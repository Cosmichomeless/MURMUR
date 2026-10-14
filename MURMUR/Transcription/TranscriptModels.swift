import Foundation

/// One recognized word (or short run of words) and when it was said.
struct TranscriptSegment: Codable, Equatable, Sendable {
    var text: String
    /// Seconds from the start of the recording.
    var start: TimeInterval
    var duration: TimeInterval

    var end: TimeInterval { start + duration }
}

/// What a recognizer returns for one audio file.
struct Transcript: Equatable, Sendable {
    var text: String
    var segments: [TranscriptSegment]
    /// Identifier of the language that was recognized, e.g. `es-ES`.
    var localeIdentifier: String
}

/// Where a recording is in its transcription life.
enum TranscriptionStatus: String, Sendable {
    /// Never asked for (older notes, or transcription switched off).
    case notRequested
    /// Queued or running. A relaunch picks these up again.
    case pending
    case completed
    case failed
}

/// Why the last attempt failed. Persisted as a code and turned into words only when shown, so the
/// message follows the language the app is displayed in.
enum TranscriptionFailure: String, Sendable {
    case notAuthorized
    case languageUnsupported
    case onDeviceUnavailable
    case noSpeech
    case failed
}

/// The errors a `SpeechEngine` can throw. Anything else is reported as `.failed`.
enum TranscriptionError: Error, Equatable, Sendable {
    case notAuthorized
    case languageUnsupported
    case onDeviceUnavailable
    case noSpeech
    case failed(String)

    var failure: TranscriptionFailure {
        switch self {
        case .notAuthorized: .notAuthorized
        case .languageUnsupported: .languageUnsupported
        case .onDeviceUnavailable: .onDeviceUnavailable
        case .noSpeech: .noSpeech
        case .failed: .failed
        }
    }
}

/// Encodes the word timings stored in `Recording.transcriptSegmentsData`.
enum TranscriptSegmentCodec {
    static func encode(_ segments: [TranscriptSegment]) -> Data? {
        segments.isEmpty ? nil : try? JSONEncoder().encode(segments)
    }

    static func decode(_ data: Data?) -> [TranscriptSegment] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([TranscriptSegment].self, from: data)) ?? []
    }
}

/// A readable run of the transcript with the moment it starts, for showing and tapping to seek.
struct TranscriptLine: Equatable, Identifiable, Sendable {
    let id: Int
    let text: String
    let start: TimeInterval

    /// Groups words into lines: a new line starts after a pause or when the line gets long.
    ///
    /// - Parameters:
    ///   - pause: Silence, in seconds, that ends a line.
    ///   - maxWords: Longest line, in segments.
    ///   - separator: What goes between two segments. Empty for languages written without spaces.
    static func lines(
        from segments: [TranscriptSegment],
        pause: TimeInterval = 1.0,
        maxWords: Int = 14,
        separator: String = " "
    ) -> [TranscriptLine] {
        var lines: [TranscriptLine] = []
        var words: [String] = []
        var start: TimeInterval = 0
        var lastEnd: TimeInterval = 0

        func flush() {
            guard !words.isEmpty else { return }
            lines.append(TranscriptLine(id: lines.count, text: words.joined(separator: separator), start: start))
            words = []
        }

        for segment in segments {
            let word = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !word.isEmpty else { continue }
            if !words.isEmpty, segment.start - lastEnd >= pause || words.count >= maxWords {
                flush()
            }
            if words.isEmpty { start = segment.start }
            words.append(word)
            lastEnd = segment.end
        }
        flush()
        return lines
    }

    /// `""` for languages that are written without spaces between words, `" "` otherwise.
    static func separator(forLocaleIdentifier identifier: String?) -> String {
        guard let identifier else { return " " }
        let language = Locale(identifier: identifier).language.languageCode?.identifier
        return ["ja", "zh", "th"].contains(language) ? "" : " "
    }
}
