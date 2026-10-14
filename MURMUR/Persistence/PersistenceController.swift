import Foundation
import SwiftData

enum PersistenceController {
    /// The newest schema. Stores written by older versions are migrated by `MurmurMigrationPlan`.
    static let schema = Schema(versionedSchema: MurmurSchemaV4.self)

    /// The app's container. `inMemory` is for tests and previews; `storeURL` pins the on-disk
    /// location (tests use it to simulate a relaunch against the same store).
    ///
    /// With `sync` the notes' metadata is mirrored to the user's private iCloud database. Never
    /// combined with `inMemory`: a demo or test run must not touch anyone's iCloud.
    static func makeContainer(inMemory: Bool = false, storeURL: URL? = nil, sync: Bool = false) throws -> ModelContainer {
        let cloud: ModelConfiguration.CloudKitDatabase = sync && !inMemory ? .private(CloudKitConfig.containerIdentifier) : .none
        let configuration: ModelConfiguration
        if let storeURL {
            configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: cloud)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: cloud)
        }
        return try ModelContainer(for: schema, migrationPlan: MurmurMigrationPlan.self, configurations: [configuration])
    }
}

enum CloudKitConfig {
    /// Declared in `MURMUR.entitlements`. Notes live in the user's own private database of it.
    static let containerIdentifier = "iCloud.com.cosmichomeless.murmur"
    /// The custom zone that holds the audio records (`CKSyncEngine` needs a custom zone).
    static let audioZoneName = "MurmurAudio"
    static let audioRecordType = "Audio"
}
