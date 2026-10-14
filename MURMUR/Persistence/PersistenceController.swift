import Foundation
import SwiftData

enum PersistenceController {
    /// The newest schema. Stores written by older versions are migrated by `MurmurMigrationPlan`.
    static let schema = Schema(versionedSchema: MurmurSchemaV2.self)

    /// The app's container. `inMemory` is for tests and previews; `storeURL` pins the on-disk
    /// location (tests use it to simulate a relaunch against the same store).
    static func makeContainer(inMemory: Bool = false, storeURL: URL? = nil) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if let storeURL {
            configuration = ModelConfiguration(schema: schema, url: storeURL)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        }
        return try ModelContainer(for: schema, migrationPlan: MurmurMigrationPlan.self, configurations: [configuration])
    }
}
