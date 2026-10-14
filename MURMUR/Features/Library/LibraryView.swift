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
    @State private var isShowingSettings = false
    @State private var path: [PlayerRoute] = []
    @State private var searchText = ""
    @State private var selectedTag: String?
    @State private var editing: Recording?
    @State private var pendingDeletion: Recording?
    @State private var deletionMessage: String?
    @State private var editMode: EditMode = .inactive
    @State private var selection = Set<Recording.ID>()
    @State private var sharing = ShareCoordinator()

    private var isSelecting: Bool { editMode.isEditing }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if recordings.isEmpty {
                    EmptyLibraryView()
                } else {
                    resultsList
                }
            }
            .navigationTitle("MURMUR")
            .searchable(text: $searchText, prompt: "Search titles, tags and transcripts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { isShowingSettings = true }
                        .accessibilityIdentifier("library.settings")
                }
                if !recordings.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(isSelecting ? "Done" : "Select") {
                            withAnimation { editMode = isSelecting ? .inactive : .active }
                        }
                        .accessibilityIdentifier("library.select")
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .onChange(of: editMode) { if !isSelecting { selection.removeAll() } }
            .shareSheet(sharing)
            .sheet(isPresented: $isShowingSettings) { SettingsView() }
            .sheet(item: $editing) { recording in
                RecordingDetailsSheet(recording: recording, repository: repository)
            }
            .navigationDestination(for: PlayerRoute.self) { route in
                PlayerView(
                    recording: route.recording,
                    fileURL: route.recording.fileURL(in: repository.fileStore),
                    startTime: route.startTime,
                    repository: repository,
                    model: player
                )
            }
            .safeAreaInset(edge: .bottom) {
                if isSelecting {
                    selectionBar
                } else {
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
            path = [PlayerRoute(recording: recording)]
            try? await Task.sleep(for: .milliseconds(800))
            // Paused partway through, so every capture shows the same frame.
            player.seek(to: recording.duration * 0.35)
        }
    }
}
#endif

extension LibraryView {
    private var tags: [String] { RecordingRepository.tagUsage(in: recordings) }

    private var results: [RecordingSearchResult] {
        RecordingSearch.results(for: searchText, in: recordings, tag: selectedTag)
    }

    private var isFiltering: Bool {
        selectedTag != nil || !RecordingSearch.terms(in: searchText).isEmpty
    }

    @ViewBuilder
    private var resultsList: some View {
        let shown = results
        List(selection: $selection) {
            if !tags.isEmpty {
                TagFilterBar(tags: tags, selection: $selectedTag)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            ForEach(shown) { result in
                NavigationLink(value: PlayerRoute(recording: result.recording, startTime: result.moment?.time)) {
                    RecordingRow(recording: result.recording, moment: result.moment)
                }
                .swipeActions(edge: .leading) {
                    Button("Edit", systemImage: "pencil") { editing = result.recording }
                        .tint(Brand.coral)
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        pendingDeletion = result.recording
                    }
                }
            }
        }
        .overlay {
            if shown.isEmpty, isFiltering {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    /// Replaces the record button while notes are being picked: share the picked notes, or all shown.
    private var selectionBar: some View {
        let picked = recordings.filter { selection.contains($0.id) }
        return HStack {
            Text(picked.isEmpty ? "Select notes to share" : "\(picked.count) selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Menu {
                ForEach(ShareChoice.allCases) { choice in
                    Button(choice.title, systemImage: choice.symbol) {
                        sharing.share(picked, choice: choice, fileStore: repository.fileStore)
                    }
                }
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .disabled(picked.isEmpty || sharing.isPreparing)
            .accessibilityIdentifier("library.shareSelected")
        }
        .padding(.horizontal)
        .padding(.vertical, Brand.Spacing.small)
        .background(.bar)
    }

    private func delete(_ recording: Recording) {
        do {
            // A leftover file (`.fileLeftBehind`) is invisible to the user and swept at next launch.
            try repository.delete(recording)
        } catch {
            deletionMessage = error.localizedDescription
        }
    }
}

/// Where a tap on a note goes: the player, optionally at a moment found by a search.
struct PlayerRoute: Hashable {
    let recording: Recording
    var startTime: TimeInterval?
}

/// A row of chips to show only the notes with one tag. Tapping the chosen tag clears the filter.
private struct TagFilterBar: View {
    let tags: [String]
    @Binding var selection: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Brand.Spacing.small) {
                ForEach(tags, id: \.self) { tag in
                    let isSelected = selection.map(TagList.key) == TagList.key(tag)
                    Button {
                        selection = isSelected ? nil : tag
                    } label: {
                        Text("#\(tag)")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .background(isSelected ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(.quaternary), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
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
