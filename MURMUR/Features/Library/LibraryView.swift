import SwiftData
import SwiftUI

/// The home screen: every saved recording, newest first, and the entry point to record.
struct LibraryView: View {
    let microphoneAccess: MicrophoneAccess
    let recorder: RecorderViewModel
    let repository: RecordingRepository

    @Query(Recording.newestFirst()) private var recordings: [Recording]
    @State private var isRecording = false
    @State private var pendingDeletion: Recording?
    @State private var deletionMessage: String?

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
                            .swipeActions(edge: .trailing) {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    pendingDeletion = recording
                                }
                            }
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
            .confirmationDialog(
                "Delete this recording?",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingDeletion
            ) { recording in
                Button("Delete \"\(recording.title)\"", role: .destructive) { delete(recording) }
            } message: { _ in
                Text("The audio file will be removed from this device. This can't be undone.")
            }
            .alert("Couldn't delete", isPresented: Binding(
                get: { deletionMessage != nil },
                set: { if !$0 { deletionMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deletionMessage ?? "")
            }
            .sheet(isPresented: $isRecording) {
                RecorderSheet(model: recorder, access: microphoneAccess)
            }
        }
    }
}

extension LibraryView {
    private func delete(_ recording: Recording) {
        do {
            // A leftover file (`.fileLeftBehind`) is invisible to the user and swept at next launch.
            try repository.delete(recording)
        } catch {
            deletionMessage = error.localizedDescription
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
