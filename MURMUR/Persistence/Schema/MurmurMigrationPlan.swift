import SwiftData

/// Every released schema in order, and how to move between them.
///
/// Both steps so far only add optional or defaulted properties, so SwiftData can migrate them
/// itself. Add a new `MurmurSchemaVN` and a stage here whenever the model changes; never edit an
/// old version.
enum MurmurMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [MurmurSchemaV1.self, MurmurSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: MurmurSchemaV1.self, toVersion: MurmurSchemaV2.self)]
    }
}
