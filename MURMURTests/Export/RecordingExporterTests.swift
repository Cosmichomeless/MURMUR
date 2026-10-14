import Foundation
import Testing
@testable import MURMUR

@Suite("RecordingExporter")
struct RecordingExporterTests {
    private func makeExporter() -> RecordingExporter {
        RecordingExporter(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("ExportTests-\(UUID().uuidString)", isDirectory: true))
    }

    private func makeAudio(_ bytes: String = "audio") throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        try Data(bytes.utf8).write(to: url)
        return url
    }

    private func note(
        title: String = "Ideas",
        audio: URL,
        text: String? = "Hello world. Second thought.",
        segments: [TranscriptSegment] = [],
        edited: Bool = false,
        tags: [String] = []
    ) -> ExportableNote {
        ExportableNote(
            title: title,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            duration: 75,
            tags: tags,
            audioURL: audio,
            transcriptText: text,
            segments: segments,
            localeIdentifier: "en_US",
            isTranscriptEdited: edited
        )
    }

    @Test func audioKeepsItsBytesAndTakesTheTitleAsName() throws {
        let exporter = makeExporter()
        defer { exporter.removeAll() }
        let urls = try exporter.export([note(title: "Trip plan", audio: try makeAudio("abc"))], content: .audio)
        #expect(urls.map(\.lastPathComponent) == ["Trip plan.m4a"])
        #expect(try Data(contentsOf: urls[0]) == Data("abc".utf8))
    }

    @Test func fileNamesAreSanitised() {
        #expect(RecordingExporter.baseName(for: "a/b:c?d") == "a-b-c-d")
        #expect(RecordingExporter.baseName(for: "  .hidden  ") == "hidden")
        #expect(RecordingExporter.baseName(for: "Line\none") == "Line-one")
        #expect(RecordingExporter.baseName(for: String(repeating: "x", count: 200)).count == 80)
        #expect(!RecordingExporter.baseName(for: "///").isEmpty)
    }

    @Test func notesWithTheSameTitleDoNotOverwriteEachOther() throws {
        let exporter = makeExporter()
        defer { exporter.removeAll() }
        let notes = try (0..<3).map { _ in note(title: "Memo", audio: try makeAudio()) }
        let names = try exporter.export(notes, content: .audio).map(\.lastPathComponent)
        #expect(names == ["Memo.m4a", "Memo 2.m4a", "Memo 3.m4a"])
    }

    @Test func plainTextHasTitleDetailsTagsAndTranscript() throws {
        let exporter = makeExporter()
        defer { exporter.removeAll() }
        let urls = try exporter.export([note(audio: try makeAudio(), tags: ["work", "ideas"])], content: .transcriptText)
        #expect(urls.map(\.lastPathComponent) == ["Ideas.txt"])
        let text = try String(contentsOf: urls[0], encoding: .utf8)
        #expect(text.hasPrefix("Ideas\n"))
        #expect(text.contains("work, ideas"))
        #expect(text.hasSuffix("Hello world. Second thought.\n"))
    }

    @Test func markdownHasHeadingTagsAndTimedLines() throws {
        let segments = [
            TranscriptSegment(text: "Hello", start: 0, duration: 0.5),
            TranscriptSegment(text: "world", start: 0.5, duration: 0.5),
            TranscriptSegment(text: "Later", start: 65, duration: 1),
        ]
        let markdown = RecordingExporter.markdown(for: note(audio: URL(fileURLWithPath: "/x"), segments: segments, tags: ["big idea"]))
        #expect(markdown.hasPrefix("# Ideas\n"))
        #expect(markdown.contains("#big-idea"))
        #expect(markdown.contains("**0:00** Hello world"))
        #expect(markdown.contains("**1:05** Later"))
    }

    @Test func editedTranscriptIsExportedAsWrittenWithoutTimings() {
        let segments = [TranscriptSegment(text: "old", start: 0, duration: 1)]
        let markdown = RecordingExporter.markdown(
            for: note(audio: URL(fileURLWithPath: "/x"), text: "The new text", segments: segments, edited: true)
        )
        #expect(markdown.contains("The new text"))
        #expect(!markdown.contains("old"))
        #expect(!markdown.contains("**0:00**"))
    }

    @Test func notesWithoutTranscriptAreSkippedForTranscriptFiles() throws {
        let exporter = makeExporter()
        defer { exporter.removeAll() }
        let blank = note(title: "Blank", audio: try makeAudio(), text: "  \n")
        let none = note(title: "None", audio: try makeAudio(), text: nil)
        #expect(try exporter.export([blank, none], content: .transcriptMarkdown).isEmpty)
        let both = try exporter.export([blank], content: [.audio, .transcriptMarkdown])
        #expect(both.map(\.lastPathComponent) == ["Blank.m4a"])
    }

    @Test func audioAndTranscriptComeOutTogether() throws {
        let exporter = makeExporter()
        defer { exporter.removeAll() }
        let urls = try exporter.export([note(audio: try makeAudio())], content: [.audio, .transcriptMarkdown])
        #expect(urls.map(\.lastPathComponent) == ["Ideas.m4a", "Ideas.md"])
    }

    @Test func aMissingAudioFileThrowsInsteadOfExportingNothing() {
        let exporter = makeExporter()
        defer { exporter.removeAll() }
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("nope.m4a")
        #expect(throws: (any Error).self) { try exporter.export([note(audio: missing)], content: .audio) }
    }

    @Test func eachExportStartsFromAnEmptyFolder() throws {
        let exporter = makeExporter()
        defer { exporter.removeAll() }
        let first = try exporter.export([note(audio: try makeAudio())], content: .audio)
        _ = try exporter.export([note(audio: try makeAudio())], content: .audio)
        #expect(!FileManager.default.fileExists(atPath: first[0].path))
    }
}
