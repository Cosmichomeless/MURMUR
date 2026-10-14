import Foundation

/// What to put in an export. Combine them to share the audio together with its text.
struct ExportContent: OptionSet, Sendable {
    let rawValue: Int

    static let audio = ExportContent(rawValue: 1 << 0)
    static let transcriptText = ExportContent(rawValue: 1 << 1)
    static let transcriptMarkdown = ExportContent(rawValue: 1 << 2)
}

/// Everything the exporter reads from a note, copied out of the model so the work can run off the
/// main actor.
struct ExportableNote: Sendable {
    var title: String
    var createdAt: Date
    var duration: TimeInterval
    var tags: [String]
    var audioURL: URL
    var transcriptText: String?
    var segments: [TranscriptSegment]
    var localeIdentifier: String?
    /// `true` when the text was edited, so the word timings no longer match it.
    var isTranscriptEdited: Bool

    var hasTranscript: Bool {
        !(transcriptText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Builds the files a note is shared or saved as: the `.m4a`, and its transcript as `.txt` or `.md`.
///
/// Files are written to a fresh folder in the temporary directory and named after the note's title,
/// so what lands in Files or a message is readable. The audio is hard-linked when possible: sharing
/// a long recording must not copy it.
struct RecordingExporter: Sendable {
    /// Parent of every export. Wiped before each new export; the system also clears temporary files.
    let directory: URL

    init(directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("Export", isDirectory: true)) {
        self.directory = directory
    }

    /// Writes the requested files for every note and returns their locations, note by note.
    ///
    /// Notes with no transcript are left out of the transcript files rather than exported empty.
    /// Returns an empty list when there was nothing to write.
    func export(_ notes: [ExportableNote], content: ExportContent) throws -> [URL] {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: directory)
        let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)

        var used = Set<String>()
        var urls: [URL] = []
        for note in notes {
            let base = Self.baseName(for: note.title)
            if content.contains(.audio) {
                let url = folder.appendingPathComponent(uniqueName(base, "m4a", used: &used))
                try Self.place(note.audioURL, at: url)
                urls.append(url)
            }
            guard note.hasTranscript else { continue }
            if content.contains(.transcriptText) {
                let url = folder.appendingPathComponent(uniqueName(base, "txt", used: &used))
                try Self.plainText(for: note).write(to: url, atomically: true, encoding: .utf8)
                urls.append(url)
            }
            if content.contains(.transcriptMarkdown) {
                let url = folder.appendingPathComponent(uniqueName(base, "md", used: &used))
                try Self.markdown(for: note).write(to: url, atomically: true, encoding: .utf8)
                urls.append(url)
            }
        }
        return urls
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - Names

    /// A title made safe to use as a file name: no path separators or characters other systems reject.
    static func baseName(for title: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:?*|\"<>%").union(.controlCharacters).union(.newlines)
        let cleaned = title.unicodeScalars
            .map { forbidden.contains($0) ? "-" : String($0) }
            .joined()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". -"))
        let shortened = String(cleaned.prefix(80)).trimmingCharacters(in: CharacterSet(charactersIn: ". -"))
        return shortened.isEmpty ? String(localized: "Recording") : shortened
    }

    private func uniqueName(_ base: String, _ ext: String, used: inout Set<String>) -> String {
        var name = "\(base).\(ext)"
        var counter = 2
        while !used.insert(name.lowercased()).inserted {
            name = "\(base) \(counter).\(ext)"
            counter += 1
        }
        return name
    }

    private static func place(_ source: URL, at destination: URL) throws {
        let fileManager = FileManager.default
        do {
            try fileManager.linkItem(at: source, to: destination)
        } catch {
            try fileManager.copyItem(at: source, to: destination)
        }
    }

    // MARK: - Text

    static func plainText(for note: ExportableNote) -> String {
        var header = [note.title, details(of: note)]
        if !note.tags.isEmpty {
            header.append("\(String(localized: "Tags")): \(note.tags.joined(separator: ", "))")
        }
        return header.joined(separator: "\n") + "\n\n" + (note.transcriptText ?? "") + "\n"
    }

    static func markdown(for note: ExportableNote) -> String {
        var lines = ["# \(note.title)", "", "*\(details(of: note))*"]
        if !note.tags.isEmpty {
            lines += ["", note.tags.map { "#" + $0.replacingOccurrences(of: " ", with: "-") }.joined(separator: " ")]
        }
        lines.append("")
        if note.isTranscriptEdited || note.segments.isEmpty {
            lines.append(note.transcriptText ?? "")
        } else {
            let separator = TranscriptLine.separator(forLocaleIdentifier: note.localeIdentifier)
            for line in TranscriptLine.lines(from: note.segments, separator: separator) {
                lines += ["**\(DurationFormat.clock(line.start))** \(line.text)", ""]
            }
            lines.removeLast()
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func details(of note: ExportableNote) -> String {
        let date = note.createdAt.formatted(date: .long, time: .shortened)
        return "\(date) · \(DurationFormat.clock(note.duration))"
    }
}

extension Recording {
    /// A copy of what an export needs, safe to hand to another thread.
    func exportable(in fileStore: RecordingFileStore) -> ExportableNote {
        ExportableNote(
            title: title,
            createdAt: createdAt,
            duration: duration,
            tags: tags,
            audioURL: fileURL(in: fileStore),
            transcriptText: transcriptText,
            segments: transcriptSegments,
            localeIdentifier: transcriptLocaleIdentifier,
            isTranscriptEdited: isTranscriptEdited
        )
    }
}
