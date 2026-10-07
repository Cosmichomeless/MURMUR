import SwiftUI

/// Temporary shell. Replaced by the Library screen when recordings are listed.
struct RootView: View {
    var body: some View {
        ContentUnavailableView(
            "MURMUR",
            systemImage: "waveform",
            description: Text("Voice notes with a live waveform.")
        )
    }
}

#Preview {
    RootView()
}
