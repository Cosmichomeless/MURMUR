import SwiftUI

struct RootView: View {
    let microphoneAccess: MicrophoneAccess
    let recorder: RecorderViewModel
    let repository: RecordingRepository
    let player: PlayerViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        LibraryView(
            microphoneAccess: microphoneAccess,
            recorder: recorder,
            repository: repository,
            player: player
        )
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    microphoneAccess.refresh()
                }
            }
    }
}
