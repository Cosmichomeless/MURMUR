import Foundation
import SwiftData

/// The first on-disk schema: a recording is only audio metadata.
///
/// Frozen on purpose. It must keep matching what the first builds wrote, because it is the source
/// side of the migration to `MurmurSchemaV2`. Never edit it; add a new version instead.
enum MurmurSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] { [Recording.self] }

    @Model
    final class Recording {
        @Attribute(.unique) var id: UUID
        var title: String
        var fileName: String
        var duration: TimeInterval
        var createdAt: Date
        var waveformData: Data

        init(
            id: UUID = UUID(),
            title: String,
            fileName: String,
            duration: TimeInterval,
            createdAt: Date = .now,
            waveformData: Data = Data()
        ) {
            self.id = id
            self.title = title
            self.fileName = fileName
            self.duration = duration
            self.createdAt = createdAt
            self.waveformData = waveformData
        }
    }
}
