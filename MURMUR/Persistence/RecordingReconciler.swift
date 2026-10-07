import Foundation
import SwiftData

/// The differences between the files on disk and the metadata in the store.
struct ReconciliationPlan: Equatable {
    /// Audio files that no `Recording` references (left by a crash between steps of save/delete).
    var orphanFiles: [String] = []
    /// Recordings whose audio file no longer exists (removed externally); they cannot be played.
    var recordingsMissingFile: [UUID] = []

    var isConsistent: Bool { orphanFiles.isEmpty && recordingsMissingFile.isEmpty }
}

struct ReconciliationReport: Equatable {
    var removedOrphanFiles: Int
    var removedRecordingsMissingFile: Int
    var purgedTemporaryFiles: Int
}

enum RecordingReconciliation {
    /// Pure comparison of what is on disk with what the store knows. Order of results is stable.
    static func plan(
        storedFileNames: Set<String>,
        records: [(id: UUID, fileName: String)]
    ) -> ReconciliationPlan {
        let referenced = Set(records.map(\.fileName))
        return ReconciliationPlan(
            orphanFiles: storedFileNames.subtracting(referenced).sorted(),
            recordingsMissingFile: records
                .filter { !storedFileNames.contains($0.fileName) }
                .map(\.id)
        )
    }
}

/// Brings metadata and files back in sync. Run once at launch, before any UI can save or delete.
///
/// It only mutates after both sides were read successfully: a failed fetch or directory listing
/// throws and deletes nothing, so a transient error can never wipe the library.
@MainActor
struct RecordingReconciler {
    let context: ModelContext
    let fileStore: RecordingFileStore

    @discardableResult
    func run() throws -> ReconciliationReport {
        try fileStore.prepareDirectories()

        let recordings = try context.fetch(FetchDescriptor<Recording>())
        let storedFiles = try fileStore.storedFileNames()
        let plan = RecordingReconciliation.plan(
            storedFileNames: storedFiles,
            records: recordings.map { ($0.id, $0.fileName) }
        )

        // Metadata first: a recording without audio is broken, an extra file is only wasted space.
        let missing = Set(plan.recordingsMissingFile)
        for recording in recordings where missing.contains(recording.id) {
            context.delete(recording)
        }
        if !missing.isEmpty {
            try context.save()
        }

        for fileName in plan.orphanFiles {
            try fileStore.remove(fileName: fileName)
        }
        let purged = try fileStore.purgeTemporaryFiles()

        return ReconciliationReport(
            removedOrphanFiles: plan.orphanFiles.count,
            removedRecordingsMissingFile: missing.count,
            purgedTemporaryFiles: purged
        )
    }
}
