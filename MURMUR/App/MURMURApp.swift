import SwiftData
import SwiftUI

@main
struct MURMURApp: App {
    private let container: ModelContainer
    @State private var microphoneAccess: MicrophoneAccess
    @State private var recorder: RecorderViewModel
    @State private var player: PlayerViewModel
    @State private var transcription: TranscriptionService
    @State private var syncSettings: SyncSettings
    private let repository: RecordingRepository

    init() {
        let services = AppServices.make()
        let fileStore = services.fileStore
        try? fileStore.prepareDirectories()

        // iCloud is opt-in and a demo run never uses it. If the store cannot be opened with iCloud
        // (no entitlement, no account), open it the normal way: the library must always open.
        let syncSettings = SyncSettings()
        let container: ModelContainer
        var syncActive = false
        do {
            if !services.inMemory, SyncSettings.requested() {
                do {
                    container = try PersistenceController.makeContainer(sync: true)
                    syncActive = true
                } catch {
                    syncSettings.lastIssue = .unavailable
                    container = try PersistenceController.makeContainer()
                }
            } else {
                container = try PersistenceController.makeContainer(inMemory: services.inMemory)
            }
        } catch {
            fatalError("Could not open the recordings store: \(error)")
        }
        syncSettings.markActive(syncActive)
        _syncSettings = State(initialValue: syncSettings)
        self.container = container
        let context = container.mainContext

        // Bring files and metadata back in line after a crash or interrupted save.
        _ = try? RecordingReconciler(context: context, fileStore: fileStore, syncEnabled: syncActive).run()

        var unsynced = RecordingRepository(context: context, fileStore: fileStore)
        if syncActive {
            let audioSync = CloudKitAudioSync(
                fileStore: fileStore,
                onAudioArrived: { Task { @MainActor in syncSettings.audioDidArrive() } },
                onIssue: { issue in Task { @MainActor in syncSettings.lastIssue = issue } }
            )
            audioSync.start()
            unsynced.audioSync = audioSync
        }
        let repository = unsynced
        self.repository = repository
        try? services.seedLibrary?(repository)

        let transcription = TranscriptionService(
            engine: services.speech,
            repository: repository,
            settings: TranscriptionSettings()
        )
        _transcription = State(initialValue: transcription)

        let session = services.session
        let access = MicrophoneAccess(session: session)
        let events = AudioSessionEvents()
        _player = State(initialValue: PlayerViewModel(player: AudioPlayer(), session: session, events: events))
        _microphoneAccess = State(initialValue: access)
        _recorder = State(initialValue: RecorderViewModel(
            access: access,
            recorder: services.recorder,
            events: events,
            activity: services.activity,
            save: { audio in
                let recording = try repository.save(
                    temporaryURL: audio.fileURL,
                    duration: audio.duration,
                    waveform: audio.waveform
                )
                transcription.transcribeAfterSave(recording)
            }
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                microphoneAccess: microphoneAccess,
                recorder: recorder,
                repository: repository,
                player: player
            )
            .environment(transcription)
            .environment(syncSettings)
        }
        .modelContainer(container)
    }
}
