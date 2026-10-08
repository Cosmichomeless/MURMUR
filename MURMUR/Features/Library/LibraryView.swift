import SwiftData
import SwiftUI

/// The home screen: every saved recording, newest first, and the entry point to record.
struct LibraryView: View {
    let microphoneAccess: MicrophoneAccess
    let recorder: RecorderViewModel
    let repository: RecordingRepository
    let player: PlayerViewModel

    @Query(Recording.newestFirst()) private var recordings: [Recording]
    @State private var isRecording = false
    @State private var path: [Recording] = []
    @State private var pendingDeletion: Recording?
    @State private var deletionMessage: String?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if recordings.isEmpty {
                    EmptyLibraryView()
                } else {
                    List(recordings) { recording in
                        NavigationLink(value: recording) {
                            RecordingRow(recording: recording)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                pendingDeletion = recording
                            }
                        }
                    }
                }
            }
            .navigationTitle("MURMUR")
            .navigationDestination(for: Recording.self) { recording in
                PlayerView(
                    recording: recording,
                    fileURL: recording.fileURL(in: repository.fileStore),
                    model: player
                )
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    // Capture and playback must not overlap: they need different session categories.
                    player.stop()
                    isRecording = true
                } label: {
                    Image(systemName: "mic.fill")
                }
                .buttonStyle(BrandRoundButtonStyle(kind: .accent, size: 64))
                .accessibilityLabel("Record")
                .padding(.bottom, Brand.Spacing.small)
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
        #if DEBUG
        .task { await openDemoScreen() }
        #endif
    }
}

#if DEBUG
extension LibraryView {
    /// `-murmur-demo-screen recorder|player`: lands on a screen that otherwise needs taps, so the
    /// screenshots can be retaken from the command line.
    private func openDemoScreen() async {
        guard let screen = DemoMode.startScreen else { return }
        try? await Task.sleep(for: .milliseconds(600))
        switch screen {
        case .recorder:
            isRecording = true
            try? await Task.sleep(for: .milliseconds(800))
            await recorder.start()
        case .player:
            guard let recording = recordings.first(where: { $0.title == DemoLibrary.playerTitle }) else { return }
            path = [recording]
            try? await Task.sleep(for: .milliseconds(800))
            // Paused partway through, so every capture shows the same frame.
            player.seek(to: recording.duration * 0.35)
        }
    }
}
#endif

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
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
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

/// Shown before the first recording: the icon's tile and a pointer to the record button.
private struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: Brand.Spacing.medium) {
            Image(systemName: "waveform")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 88, height: 88)
                .background(Brand.gradient, in: RoundedRectangle(cornerRadius: Brand.Radius.card + 6))
                .shadow(color: Brand.Shadow.color, radius: Brand.Shadow.radius, y: Brand.Shadow.offset)
                .accessibilityHidden(true)

            Text("No recordings yet")
                .font(.title3.weight(.semibold))
            Text("Tap the microphone to record your first voice note.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Brand.Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
