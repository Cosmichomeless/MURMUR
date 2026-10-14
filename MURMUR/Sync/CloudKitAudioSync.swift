import CloudKit
import Foundation
import OSLog

/// Sends the audio files to the user's private iCloud and brings the other devices' ones back.
///
/// One `CKRecord` per file in a custom zone: `recordName` is the file name (`<UUID>.m4a`) and the
/// audio is a `CKAsset`. Because a name is written once and never changes, there is nothing to
/// merge: if the server already has the name, it is done. See `docs/PERSISTENCE.md` for the rules.
///
/// `CKSyncEngine` does the scheduling (push, retries, backoff, account changes). This type only
/// says what to send, and what to do with what arrives. It could not be exercised against a real
/// CloudKit server in the project's tests; the rules it applies live in `AudioSyncRules` and
/// `RecordingFileStore.adoptDownloaded`, which are.
final class CloudKitAudioSync: AudioSyncing, CKSyncEngineDelegate, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.cosmichomeless.murmur", category: "icloud-sync")
    private static let backfilledKey = "sync.audioBackfilled"
    private static let assetField = "audio"

    private let fileStore: RecordingFileStore
    private let stateURL: URL
    private let defaults: UserDefaults
    private let zoneID = CKRecordZone.ID(zoneName: CloudKitConfig.audioZoneName)
    private let onAudioArrived: @Sendable () -> Void
    private let onIssue: @Sendable (SyncIssue?) -> Void
    // Set once in `start()`, before the object is shared.
    private var engine: CKSyncEngine?

    init(
        fileStore: RecordingFileStore,
        defaults: UserDefaults = .standard,
        onAudioArrived: @escaping @Sendable () -> Void,
        onIssue: @escaping @Sendable (SyncIssue?) -> Void
    ) {
        self.fileStore = fileStore
        self.defaults = defaults
        self.onAudioArrived = onAudioArrived
        self.onIssue = onIssue
        let support = fileStore.recordingsDirectory.deletingLastPathComponent()
        stateURL = support.appendingPathComponent("Sync", isDirectory: true).appendingPathComponent("audio-sync-state.json")
    }

    /// Starts syncing. The first time, every audio file already on the device is queued.
    func start() {
        let container = CKContainer(identifier: CloudKitConfig.containerIdentifier)
        var configuration = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: loadState(),
            delegate: self
        )
        configuration.automaticallySync = true
        let engine = CKSyncEngine(configuration)
        self.engine = engine

        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
        if !defaults.bool(forKey: Self.backfilledKey) {
            let names = ((try? fileStore.storedFileNames()) ?? []).sorted()
            engine.state.add(pendingRecordZoneChanges: names.map { .saveRecord(recordID(for: $0)) })
            defaults.set(true, forKey: Self.backfilledKey)
            Self.logger.info("Queued \(names.count) existing audio files for upload")
        }
    }

    // MARK: - AudioSyncing

    func audioAdded(fileName: String) {
        engine?.state.add(pendingRecordZoneChanges: [.saveRecord(recordID(for: fileName))])
    }

    func audioRemoved(fileName: String) {
        engine?.state.add(pendingRecordZoneChanges: [.deleteRecord(recordID(for: fileName))])
    }

    // MARK: - CKSyncEngineDelegate

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            saveState(update.stateSerialization)

        case .accountChange(let change):
            switch change.changeType {
            case .signIn:
                // A new account has none of our audio yet: send everything again.
                defaults.set(false, forKey: Self.backfilledKey)
                onIssue(nil)
            case .signOut, .switchAccounts:
                // The local audio stays: it is the user's. Only the bookkeeping of the old account goes.
                defaults.set(false, forKey: Self.backfilledKey)
                try? FileManager.default.removeItem(at: stateURL)
                onIssue(.noAccount)
            @unknown default:
                break
            }

        case .fetchedDatabaseChanges(let changes):
            // The user wiped the zone from iCloud settings: put the local audio back.
            if changes.deletions.contains(where: { $0.zoneID == zoneID }) {
                let names = ((try? fileStore.storedFileNames()) ?? []).sorted()
                syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
                syncEngine.state.add(pendingRecordZoneChanges: names.map { .saveRecord(recordID(for: $0)) })
            }

        case .fetchedRecordZoneChanges(let changes):
            var arrived = false
            for modification in changes.modifications {
                arrived = adopt(modification.record) || arrived
            }
            for deletion in changes.deletions where deletion.recordID.zoneID == zoneID {
                // The note was deleted on another device.
                try? fileStore.remove(fileName: deletion.recordID.recordName)
                arrived = true
            }
            if arrived { onAudioArrived() }

        case .sentRecordZoneChanges(let sent):
            handleFailures(of: sent, in: syncEngine)

        default:
            break
        }
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { [self] recordID in
            let name = recordID.recordName
            guard AudioSyncRules.isValidFileName(name), fileStore.exists(fileName: name) else {
                // Nothing to send any more (deleted meanwhile): drop the request.
                syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
                return nil
            }
            let record = CKRecord(recordType: CloudKitConfig.audioRecordType, recordID: recordID)
            record[Self.assetField] = CKAsset(fileURL: fileStore.fileURL(for: name))
            return record
        }
    }

    // MARK: - Private

    private func recordID(for fileName: String) -> CKRecord.ID {
        CKRecord.ID(recordName: fileName, zoneID: zoneID)
    }

    /// Stores one downloaded audio file. Returns whether a new file appeared.
    private func adopt(_ record: CKRecord) -> Bool {
        guard record.recordType == CloudKitConfig.audioRecordType,
              record.recordID.zoneID == zoneID,
              let asset = record[Self.assetField] as? CKAsset,
              let source = asset.fileURL else { return false }
        do {
            return try fileStore.adoptDownloaded(fileName: record.recordID.recordName, from: source)
        } catch {
            Self.logger.error("Could not store downloaded audio: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func handleFailures(of sent: CKSyncEngine.Event.SentRecordZoneChanges, in syncEngine: CKSyncEngine) {
        for failure in sent.failedRecordSaves {
            let id = failure.record.recordID
            switch failure.error.code {
            case .serverRecordChanged:
                // Same name already on the server: audio never changes, so it is already there.
                syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(id)])
            case .zoneNotFound:
                syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: id.zoneID))])
                syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(id)])
            case .quotaExceeded:
                onIssue(.quotaExceeded)
            case .unknownItem:
                syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(id)])
            default:
                Self.logger.error("Audio upload failed: \(failure.error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func loadState() -> CKSyncEngine.State.Serialization? {
        guard let data = try? Data(contentsOf: stateURL) else { return nil }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    private func saveState(_ state: CKSyncEngine.State.Serialization) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: stateURL, options: .atomic)
    }
}
