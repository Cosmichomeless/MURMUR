import Foundation
import SwiftData

extension Recording {
    var tags: [String] {
        get { TagList.decode(tagsRaw) }
        set { tagsRaw = TagList.encode(newValue) }
    }
}

/// Changes to the details of a note that the user can edit: its title and its tags.
extension RecordingRepository {
    /// Gives a note a new title. A blank title goes back to the default one made from the date.
    func rename(_ recording: Recording, to title: String) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let newTitle = trimmed.isEmpty ? Self.defaultTitle(for: recording.createdAt) : trimmed
        try commit { recording.title = newTitle }
    }

    func setTags(_ recording: Recording, to tags: [String]) throws {
        try commit { recording.tags = tags }
    }

    /// Title and tags in one save, so editing both never leaves the note half-changed.
    func updateDetails(_ recording: Recording, title: String, tags: [String]) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let newTitle = trimmed.isEmpty ? Self.defaultTitle(for: recording.createdAt) : trimmed
        try commit {
            recording.title = newTitle
            recording.tags = tags
        }
    }

    /// Every tag in use, most used first, then alphabetical.
    func allTags() -> [String] {
        let recordings = (try? context.fetch(FetchDescriptor<Recording>())) ?? []
        return Self.tagUsage(in: recordings)
    }

    static func tagUsage(in recordings: [Recording]) -> [String] {
        var counts: [String: (name: String, count: Int)] = [:]
        for tag in recordings.flatMap(\.tags) {
            let key = TagList.key(tag)
            counts[key, default: (tag, 0)].count += 1
        }
        return counts.values
            .sorted { ($1.count, $0.name.localizedLowercase) < ($0.count, $1.name.localizedLowercase) }
            .map(\.name)
    }
}
