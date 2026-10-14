#if DEBUG
import Foundation

/// The recordings shown in screenshots: invented titles, fixed dates, synthetic voices.
@MainActor
enum DemoLibrary {
    private struct Entry {
        let title: String
        let day: Int
        let hour: Int
        let minute: Int
        let seconds: Int
        let seed: UInt64
        let words: String
    }

    private static let entries = [
        Entry(title: "Standup notes", day: 7, hour: 9, minute: 41, seconds: 94, seed: 11, words: "Yesterday I finished the export screen and fixed the crash on rotation. Today I will review the pull request from Marta and start on the search field. Nothing is blocking me, but I need the final copy for the onboarding before Thursday."),
        Entry(title: "Idea for the weekend trip", day: 6, hour: 18, minute: 20, seconds: 37, seed: 23, words: "What about the coast this weekend? We could take the early train on Saturday, rent bikes at the harbour and book that small place for dinner. Check the weather forecast on Friday night."),
        Entry(title: "Voice memo for Ana", day: 5, hour: 12, minute: 5, seconds: 212, seed: 5, words: "Hi Ana, it is me. I went through the contract and everything looks fine except the delivery date on page four, which still says March. Could you ask them to change it to April before we sign? Also remember to bring the signed copy on Monday, and I will print the invoice and the schedule for the meeting. Call me back when you have a minute, there is nothing urgent. Thanks a lot, talk soon."),
        Entry(title: "Chapter 3 thoughts", day: 3, hour: 21, minute: 30, seconds: 128, seed: 42, words: "The middle of the chapter drags. The argument about the old harbour is strong, but it arrives too late. Move the letter scene up, cut the second description of the storm, and let the ending breathe a little more."),
        Entry(title: "Shopping list", day: 1, hour: 8, minute: 15, seconds: 18, seed: 3, words: "Oat milk, two lemons, coffee beans, tomatoes, bread from the bakery and something for Sunday dinner."),
    ]

    static func populate(_ repository: RecordingRepository) throws {
        try repository.fileStore.prepareDirectories()
        for entry in entries {
            let levels = DemoSignal.levels(
                count: Int(Double(entry.seconds) / DemoAudio.window),
                seed: entry.seed
            )
            let url = repository.fileStore.makeTemporaryURL()
            try DemoAudio.write(levels: levels, to: url)
            let duration = Double(levels.count) * DemoAudio.window
            let recording = try repository.save(
                temporaryURL: url,
                duration: duration,
                waveform: DemoAudio.waveform(for: levels),
                title: entry.title,
                createdAt: date(for: entry)
            )
            try repository.apply(
                transcript(words: entry.words, localeIdentifier: "en-US", duration: duration),
                to: recording
            )
        }
    }

    /// A transcript with the words spread evenly over the recording, with a pause after each sentence.
    nonisolated static func transcript(words text: String, localeIdentifier: String, duration: TimeInterval? = nil) -> Transcript {
        let words = text.split(separator: " ").map(String.init)
        let total = duration ?? Double(words.count) * 0.45
        let perWord = total * 0.9 / Double(max(words.count, 1))
        var segments: [TranscriptSegment] = []
        var clock = total * 0.04
        for word in words {
            segments.append(TranscriptSegment(text: word, start: clock, duration: perWord * 0.85))
            clock += perWord
            if word.hasSuffix(".") || word.hasSuffix("?") { clock += perWord * 1.5 }
        }
        return Transcript(text: text, segments: segments, localeIdentifier: localeIdentifier)
    }

    /// The recording the player screenshot opens: the longest one, so the waveform has room.
    static let playerTitle = "Voice memo for Ana"

    static var recordingCount: Int { entries.count }

    private static func date(for entry: Entry) -> Date {
        let components = DateComponents(year: 2026, month: 10, day: entry.day, hour: entry.hour, minute: entry.minute)
        return Calendar.current.date(from: components) ?? .now
    }
}
#endif
