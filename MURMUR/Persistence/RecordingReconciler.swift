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
    /// Notes with the same `id` as another one (the store no longer forbids it); the extra ones were removed.
    var removedDuplicates: Int = 0
    /// With iCloud sync on: notes whose audio has not arrived yet. They are kept.
    var recordingsAwaitingAudio: Int = 0
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

    /// How long a file without a note is left alone when sync is on.
    ///
    /// With sync the audio can arrive before the metadata describing it, so a file with no note is
    /// not necessarily garbage. Recent ones are kept until their note shows up.
    static let syncOrphanGracePeriod: TimeInterval = 7 * 24 * 60 * 60
}

/// Brings metadata and files back in sync. Run once at launch, before any UI can save or delete.
///
/// It only mutates after both sides were read successfully: a failed fetch or directory listing
/// throws and deletes nothing, so a transient error can never wipe the library.
///
/// With `syncEnabled` the two halves of a note travel separately (metadata through SwiftData's
/// CloudKit mirror, audio through `CloudKitAudioSync`), so either may be missing for a while
/// without anything being wrong: notes without audio are kept and recent files without a note are
/// kept. See `docs/PERSISTENCE.md`.
@MainActor
struct RecordingReconciler {
    let context: ModelContext
    let fileStore: RecordingFileStore
    var syncEnabled = false
    var now: Date = .now

    @discardableResult
    func run() throws -> ReconciliationReport {
        try fileStore.prepareDirectories()

        var recordings = try context.fetch(FetchDescriptor<Recording>())
        let storedFiles = try fileStore.storedFileNames()

        let duplicates = Self.duplicates(in: recordings)
        for duplicate in duplicates { context.delete(duplicate) }
        if !duplicates.isEmpty {
            recordings.removeAll { recording in duplicates.contains { $0 === recording } }
        }

        let plan = RecordingReconciliation.plan(
            storedFileNames: storedFiles,
            records: recordings.map { ($0.id, $0.fileName) }
        )

        // Metadata first: a recording without audio is broken, an extra file is only wasted space.
        // With sync on it is merely waiting for its audio, so it stays.
        let missing = Set(plan.recordingsMissingFile)
        if !syncEnabled {
            for recording in recordings where missing.contains(recording.id) {
                context.delete(recording)
            }
        }
        if !duplicates.isEmpty || (!syncEnabled && !missing.isEmpty) {
            try context.save()
        }

        var removedFiles = 0
        for fileName in plan.orphanFiles where isDisposable(fileName) {
            try fileStore.remove(fileName: fileName)
            removedFiles += 1
        }
        let purged = try fileStore.purgeTemporaryFiles()

        return ReconciliationReport(
            removedOrphanFiles: removedFiles,
            removedRecordingsMissingFile: syncEnabled ? 0 : missing.count,
            purgedTemporaryFiles: purged,
            removedDuplicates: duplicates.count,
            recordingsAwaitingAudio: syncEnabled ? missing.count : 0
        )
    }

    /// An orphan can be deleted at once without sync, and only once it is old with sync.
    private func isDisposable(_ fileName: String) -> Bool {
        guard syncEnabled else { return true }
        guard let modified = fileStore.modificationDate(fileName: fileName) else { return false }
        return now.timeIntervalSince(modified) > RecordingReconciliation.syncOrphanGracePeriod
    }

    /// The notes to remove so that every `id` appears once. The oldest note of each `id` is kept.
    static func duplicates(in recordings: [Recording]) -> [Recording] {
        var seen = Set<UUID>()
        var extras: [Recording] = []
        for recording in recordings.sorted(by: { $0.createdAt < $1.createdAt }) where !seen.insert(recording.id).inserted {
            extras.append(recording)
        }
        return extras
    }
}
