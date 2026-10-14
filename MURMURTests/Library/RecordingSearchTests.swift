import Foundation
import SwiftData
import Testing
@testable import MURMUR

@MainActor
struct RecordingSearchTests {
    @MainActor private struct Fixture {
        let store = TestStore()
        let container: ModelContainer
        let repository: RecordingRepository

        init() throws {
            container = try PersistenceController.makeContainer(inMemory: true)
            repository = RecordingRepository(context: container.mainContext, fileStore: store.fileStore)
        }

        func add(
            _ title: String,
            tags: [String] = [],
            text: String? = nil,
            segments: [TranscriptSegment] = [],
            daysAgo: Int = 0
        ) throws -> Recording {
            let date = Date(timeIntervalSince1970: 1_700_000_000 - Double(daysAgo) * 86_400)
            let recording = try repository.save(
                temporaryURL: store.writeTemporaryFile(), duration: 60, waveform: [], title: title, createdAt: date
            )
            try repository.setTags(recording, to: tags)
            if let text {
                try repository.apply(Transcript(text: text, segments: segments, localeIdentifier: "en-US"), to: recording)
            }
            return recording
        }

        func all() -> [Recording] {
            (try? container.mainContext.fetch(Recording.newestFirst())) ?? []
        }
    }

    /// Words one second apart, with a long pause before `pauseBefore`, so lines split there.
    private func segments(_ words: [String], pauseBefore: Int? = nil) -> [TranscriptSegment] {
        var clock = 0.0
        return words.enumerated().map { index, word in
            if index == pauseBefore { clock += 5 }
            defer { clock += 1 }
            return TranscriptSegment(text: word, start: clock, duration: 0.5)
        }
    }

    @Test func aBlankQueryKeepsEverythingInLibraryOrder() throws {
        let f = try Fixture(); defer { f.store.cleanUp() }
        _ = try f.add("Old", daysAgo: 5)
        _ = try f.add("New")

        let results = RecordingSearch.results(for: "   ", in: f.all())
        #expect(results.map(\.recording.title) == ["New", "Old"])
    }

    @Test func titlesTagsAndTranscriptsAreAllSearched() throws {
        let f = try Fixture(); defer { f.store.cleanUp() }
        _ = try f.add("Groceries")
        _ = try f.add("Meeting", tags: ["budget"])
        _ = try f.add("Call", text: "we talked about the roadmap")

        #expect(RecordingSearch.results(for: "grocer", in: f.all()).map(\.recording.title) == ["Groceries"])
        #expect(RecordingSearch.results(for: "budget", in: f.all()).map(\.recording.title) == ["Meeting"])
        #expect(RecordingSearch.results(for: "roadmap", in: f.all()).map(\.recording.title) == ["Call"])
    }

    @Test func caseAndAccentsDoNotMatter() throws {
        let f = try Fixture(); defer { f.store.cleanUp() }
        _ = try f.add("Reunión", text: "Hablamos del presupuesto de MAÑANA")

        #expect(RecordingSearch.results(for: "reunion", in: f.all()).count == 1)
        #expect(RecordingSearch.results(for: "manana", in: f.all()).count == 1)
        #expect(RecordingSearch.results(for: "PRESUPUESTO", in: f.all()).count == 1)
    }

    @Test func everyWordMustMatchButNotInTheSameField() throws {
        let f = try Fixture(); defer { f.store.cleanUp() }
        _ = try f.add("Trip", text: "book the train on friday")

        #expect(RecordingSearch.results(for: "trip friday", in: f.all()).count == 1)
        #expect(RecordingSearch.results(for: "trip monday", in: f.all()).isEmpty)
    }

    @Test func aTranscriptMatchJumpsToTheLineItIsIn() throws {
        let f = try Fixture(); defer { f.store.cleanUp() }
        let words = ["buy", "milk", "today", "call", "the", "plumber", "tomorrow"]
        _ = try f.add("Todo", text: words.joined(separator: " "), segments: segments(words, pauseBefore: 3))

        let result = try #require(RecordingSearch.results(for: "plumber", in: f.all()).first)
        let moment = try #require(result.moment)
        // "call" starts the second line: 3 words at 0, 1, 2, then a 5 s pause.
        #expect(moment.time == 8)
        #expect(moment.snippet == "call the plumber tomorrow")
        #expect(!result.matchesMetadata)
    }

    @Test func aLineWithEveryWordWinsOverAnEarlierLineWithOne() throws {
        let f = try Fixture(); defer { f.store.cleanUp() }
        let words = ["red", "apples", "green", "red", "pears"]
        _ = try f.add("Fruit", text: words.joined(separator: " "), segments: segments(words, pauseBefore: 2))

        let result = try #require(RecordingSearch.results(for: "red pears", in: f.all()).first)
        #expect(result.moment?.snippet == "green red pears")
    }

    @Test func anEditedTranscriptStillMatchesButHasNoTime() throws {
        let f = try Fixture(); defer { f.store.cleanUp() }
        let words = ["hello", "world"]
        let recording = try f.add("Note", text: "hello world", segments: segments(words))
        try f.repository.updateTranscript(recording, text: "hello brave new world")

        let result = try #require(RecordingSearch.results(for: "brave", in: f.all()).first)
        #expect(result.moment?.time == nil)
        #expect(result.moment?.snippet.contains("brave") == true)
    }

    @Test func titleAndTagMatchesComeBeforeTranscriptMatches() throws {
        let f = try Fixture(); defer { f.store.cleanUp() }
        _ = try f.add("Mentions budget", text: "nothing", daysAgo: 0)
        _ = try f.add("Other", text: "the budget is tight", daysAgo: 1)
        _ = try f.add("Budget review", daysAgo: 9)

        let titles = RecordingSearch.results(for: "budget", in: f.all()).map(\.recording.title)
        #expect(titles == ["Mentions budget", "Budget review", "Other"])
    }

    @Test func filteringByTagIgnoresCaseAndCombinesWithTheQuery() throws {
        let f = try Fixture(); defer { f.store.cleanUp() }
        _ = try f.add("A", tags: ["Work"], text: "plan the launch")
        _ = try f.add("B", tags: ["home"], text: "plan the launch")

        #expect(RecordingSearch.results(for: "", in: f.all(), tag: "work").map(\.recording.title) == ["A"])
        #expect(RecordingSearch.results(for: "launch", in: f.all(), tag: "home").map(\.recording.title) == ["B"])
        #expect(RecordingSearch.results(for: "nothing", in: f.all(), tag: "home").isEmpty)
    }
}
