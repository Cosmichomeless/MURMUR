import Foundation
import SwiftData

enum PersistenceController {
    static let schema = Schema([Recording.self])

    /// The app's container. `inMemory` is for tests and previews.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
