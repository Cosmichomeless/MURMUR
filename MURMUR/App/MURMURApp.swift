import SwiftUI

@main
struct MURMURApp: App {
    @State private var microphoneAccess = MicrophoneAccess(session: AudioSessionManager())

    var body: some Scene {
        WindowGroup {
            RootView(microphoneAccess: microphoneAccess)
        }
    }
}
