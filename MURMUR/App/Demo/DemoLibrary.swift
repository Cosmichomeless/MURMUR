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
    }

    private static let entries = [
        Entry(title: "Standup notes", day: 7, hour: 9, minute: 41, seconds: 94, seed: 11),
        Entry(title: "Idea for the weekend trip", day: 6, hour: 18, minute: 20, seconds: 37, seed: 23),
        Entry(title: "Voice memo for Ana", day: 5, hour: 12, minute: 5, seconds: 212, seed: 5),
        Entry(title: "Chapter 3 thoughts", day: 3, hour: 21, minute: 30, seconds: 128, seed: 42),
        Entry(title: "Shopping list", day: 1, hour: 8, minute: 15, seconds: 18, seed: 3),
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
            try repository.save(
                temporaryURL: url,
                duration: Double(levels.count) * DemoAudio.window,
                waveform: DemoAudio.waveform(for: levels),
                title: entry.title,
                createdAt: date(for: entry)
            )
        }
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
