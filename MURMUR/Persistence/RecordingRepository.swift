import Foundation
import SwiftData

/// Saves recordings so that a `Recording` never points to a missing file.
///
/// Order matters: the audio file is committed first, then the metadata. If the metadata cannot be
/// saved the file is removed again, so a failure leaves nothing behind.
@MainActor
struct RecordingRepository {
    let context: ModelContext
    let fileStore: RecordingFileStore

    /// Moves a finished capture into the recordings folder and stores its metadata.
    @discardableResult
    func save(
        temporaryURL: URL,
        duration: TimeInterval,
        waveform: [Float],
        title: String? = nil,
        createdAt: Date = .now
    ) throws -> Recording {
        let fileName = try fileStore.commit(temporaryURL: temporaryURL)
        let recording = Recording(
            title: title ?? Self.defaultTitle(for: createdAt),
            fileName: fileName,
            duration: duration,
            createdAt: createdAt,
            waveform: waveform
        )
        context.insert(recording)
        do {
            try context.save()
        } catch {
            context.rollback()
            try? fileStore.remove(fileName: fileName)
            throw error
        }
        return recording
    }

    /// Deletes the metadata first and the file second.
    ///
    /// Either order can fail halfway. Metadata first means the worst case is an orphan *file*
    /// (invisible to the user, removed by the next reconciliation), never a listed recording that
    /// cannot be played. If the metadata cannot be deleted nothing has changed and this throws.
    @discardableResult
    func delete(_ recording: Recording) throws -> RecordingDeletion {
        let fileName = recording.fileName
        context.delete(recording)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }

        do {
            try fileStore.remove(fileName: fileName)
            return .deleted
        } catch {
            return .fileLeftBehind(fileName: fileName)
        }
    }

    nonisolated static func defaultTitle(for date: Date) -> String {
        "Recording \(date.formatted(date: .abbreviated, time: .shortened))"
    }
}

enum RecordingDeletion: Equatable {
    case deleted
    /// The recording is gone but its file could not be removed; reconciliation retries at launch.
    case fileLeftBehind(fileName: String)
}

extension Recording {
    /// The library order: most recent first.
    static func newestFirst() -> FetchDescriptor<Recording> {
        FetchDescriptor<Recording>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
    }
}
