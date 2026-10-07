import Foundation
import SwiftData

enum PersistenceController {
    static let schema = Schema([Recording.self])

    /// The app's container. `inMemory` is for tests and previews; `storeURL` pins the on-disk
    /// location (tests use it to simulate a relaunch against the same store).
    static func makeContainer(inMemory: Bool = false, storeURL: URL? = nil) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if let storeURL {
            configuration = ModelConfiguration(schema: schema, url: storeURL)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
