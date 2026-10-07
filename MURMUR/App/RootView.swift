import SwiftUI

struct RootView: View {
    let microphoneAccess: MicrophoneAccess
    let recorder: RecorderViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        LibraryView(microphoneAccess: microphoneAccess, recorder: recorder)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    microphoneAccess.refresh()
                }
            }
    }
}
