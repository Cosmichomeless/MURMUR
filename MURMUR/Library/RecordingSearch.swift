import Foundation

/// One note that matches a search, and where in it the match is.
struct RecordingSearchResult: Identifiable {
    let recording: Recording
    /// The title or a tag matched.
    let matchesMetadata: Bool
    /// The first matching spot in the transcript, if the transcript matched.
    let moment: Moment?

    var id: Recording.ID { recording.id }

    struct Moment: Equatable {
        /// Where to start playing, in seconds. `nil` when the text was edited and no longer has timings.
        let time: TimeInterval?
        /// The line the match is in.
        let snippet: String
    }
}

/// Full-text search over titles, tags and transcripts, ignoring case and accents.
///
/// Every word of the query must appear somewhere in the note (title, tags or transcript), in any
/// order. Done in memory: a library of thousands of notes is still instant, and it avoids a
/// second index that could drift from the data.
enum RecordingSearch {
    /// - Returns: Matching notes, those matching by title or tag first, then newest first.
    @MainActor
    static func results(for query: String, in recordings: [Recording], tag: String? = nil) -> [RecordingSearchResult] {
        let words = terms(in: query)
        let tagKey = tag.map(TagList.key)
        let results: [RecordingSearchResult] = recordings.compactMap { recording in
            if let tagKey, !recording.tags.contains(where: { TagList.key($0) == tagKey }) { return nil }
            guard !words.isEmpty else { return RecordingSearchResult(recording: recording, matchesMetadata: false, moment: nil) }
            return match(recording, words: words)
        }
        guard !words.isEmpty else { return results }
        return results.sorted { lhs, rhs in
            if lhs.matchesMetadata != rhs.matchesMetadata { return lhs.matchesMetadata }
            return lhs.recording.createdAt > rhs.recording.createdAt
        }
    }

    /// The words of a query, folded for comparison.
    static func terms(in query: String) -> [String] {
        fold(query).split(whereSeparator: \.isWhitespace).map(String.init)
    }

    // MARK: - Private

    @MainActor
    private static func match(_ recording: Recording, words: [String]) -> RecordingSearchResult? {
        let metadata = fold(([recording.title] + recording.tags).joined(separator: " "))
        let transcript = fold(recording.transcriptText ?? "")
        var inTranscript: [String] = []
        var inMetadata = false
        for word in words {
            let inMeta = metadata.contains(word)
            let inText = transcript.contains(word)
            guard inMeta || inText else { return nil }
            if inMeta { inMetadata = true }
            if inText { inTranscript.append(word) }
        }
        let moment = inTranscript.isEmpty ? nil : moment(in: recording, words: inTranscript)
        return RecordingSearchResult(recording: recording, matchesMetadata: inMetadata, moment: moment)
    }

    /// The first line holding every matched word, or failing that the first line holding any.
    @MainActor
    private static func moment(in recording: Recording, words: [String]) -> RecordingSearchResult.Moment? {
        let text = recording.transcriptText ?? ""
        let segments = recording.transcriptSegments
        if !recording.isTranscriptEdited, !segments.isEmpty {
            let lines = TranscriptLine.lines(
                from: segments,
                separator: TranscriptLine.separator(forLocaleIdentifier: recording.transcriptLocaleIdentifier)
            )
            let folded = lines.map { fold($0.text) }
            let index = folded.firstIndex { line in words.allSatisfy(line.contains) }
                ?? folded.firstIndex { line in words.contains(where: line.contains) }
            if let index { return .init(time: lines[index].start, snippet: lines[index].text) }
        }
        return .init(time: nil, snippet: snippet(in: text, around: words))
    }

    /// A short piece of `text` around the first matched word, for when there are no timings.
    private static func snippet(in text: String, around words: [String]) -> String {
        let folded = fold(text)
        let hit = words.compactMap { folded.range(of: $0)?.lowerBound }.min()
        guard let hit else { return String(text.prefix(80)) }
        // Folding can change the length (e.g. ß), so go through the character offset, not the index.
        let offset = folded.distance(from: folded.startIndex, to: hit)
        let start = text.index(text.startIndex, offsetBy: max(offset - 30, 0), limitedBy: text.endIndex) ?? text.startIndex
        let end = text.index(start, offsetBy: 90, limitedBy: text.endIndex) ?? text.endIndex
        return String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
