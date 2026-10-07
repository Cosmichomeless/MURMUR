import SwiftData
import SwiftUI

@main
struct MURMURApp: App {
    private let container: ModelContainer
    @State private var microphoneAccess: MicrophoneAccess
    @State private var recorder: RecorderViewModel
    @State private var player: PlayerViewModel
    private let repository: RecordingRepository

    init() {
        let fileStore = RecordingFileStore.default
        try? fileStore.prepareDirectories()

        let container: ModelContainer
        do {
            container = try PersistenceController.makeContainer()
        } catch {
            fatalError("Could not open the recordings store: \(error)")
        }
        self.container = container
        let context = container.mainContext

        // Bring files and metadata back in line after a crash or interrupted save.
        _ = try? RecordingReconciler(context: context, fileStore: fileStore).run()

        let repository = RecordingRepository(context: context, fileStore: fileStore)
        self.repository = repository
        let session = AudioSessionManager()
        let access = MicrophoneAccess(session: session)
        _player = State(initialValue: PlayerViewModel(player: AudioPlayer(), session: session))
        let audioRecorder = AudioRecorder(
            makeTemporaryURL: { fileStore.makeTemporaryURL() },
            removeFile: { fileStore.removeTemporary(at: $0) }
        )
        _microphoneAccess = State(initialValue: access)
        _recorder = State(initialValue: RecorderViewModel(
            access: access,
            recorder: audioRecorder,
            save: { audio in
                try repository.save(
                    temporaryURL: audio.fileURL,
                    duration: audio.duration,
                    waveform: audio.waveform
                )
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
        }
        .modelContainer(container)
    }
}
