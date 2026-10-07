import SwiftData
import SwiftUI

/// The home screen: every saved recording, newest first, and the entry point to record.
struct LibraryView: View {
    let microphoneAccess: MicrophoneAccess
    let recorder: RecorderViewModel

    @Query(Recording.newestFirst()) private var recordings: [Recording]
    @State private var isRecording = false

    var body: some View {
        NavigationStack {
            Group {
                if recordings.isEmpty {
                    ContentUnavailableView(
                        "No recordings yet",
                        systemImage: "waveform",
                        description: Text("Tap the microphone to record your first voice note.")
                    )
                } else {
                    List(recordings) { recording in
                        RecordingRow(recording: recording)
                    }
                }
            }
            .navigationTitle("MURMUR")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isRecording = true
                    } label: {
                        Label("Record", systemImage: "mic.fill")
                    }
                }
            }
            .sheet(isPresented: $isRecording) {
                RecorderSheet(model: recorder, access: microphoneAccess)
            }
        }
    }
}

/// The recorder as a modal. It closes itself once a recording is saved.
private struct RecorderSheet: View {
    let model: RecorderViewModel
    let access: MicrophoneAccess
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            RecorderView(model: model, access: access)
                .toolbar {
                    if !model.state.isCapturing {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { dismiss() }
                        }
                    }
                }
        }
        .interactiveDismissDisabled(model.state.isCapturing)
        .onChange(of: model.savedCount) { dismiss() }
    }
}
