import SwiftUI

/// The transcript under the player: its progress or error, the text (tap a line to jump to it)
/// and the actions to edit, redo or copy it.
struct TranscriptSection: View {
    let recording: Recording
    let repository: RecordingRepository
    let model: PlayerViewModel

    @Environment(TranscriptionService.self) private var transcription
    @Environment(\.openURL) private var openURL
    @State private var isEditing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Spacing.small) {
            header
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $isEditing) {
            TranscriptEditor(text: recording.transcriptText ?? "") { newText in
                do {
                    try repository.updateTranscript(recording, text: newText)
                    isEditing = false
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
        .alert("Couldn't save", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Transcript")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if recording.isTranscriptEdited {
                Text("Edited")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.2), in: Capsule())
            }
            Spacer()
            if !isBusy { menu }
        }
    }

    private var menu: some View {
        Menu {
            if recording.hasTranscript {
                Button("Edit text", systemImage: "pencil") { isEditing = true }
                Button("Copy text", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = recording.transcriptText
                }
                if recording.isTranscriptEdited {
                    Button("Restore original", systemImage: "arrow.uturn.backward") { restoreOriginal() }
                }
            }
            Button("Transcribe again", systemImage: "arrow.clockwise") {
                transcription.transcribe(recording)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("Transcript options")
        .accessibilityIdentifier("transcript.menu")
    }

    // MARK: - Content

    private var isBusy: Bool {
        transcription.isBusy(recording) || recording.transcriptionStatus == .pending
    }

    @ViewBuilder
    private var content: some View {
        if isBusy {
            HStack(spacing: Brand.Spacing.small) {
                ProgressView().tint(Brand.onGradient)
                Text("Transcribing on this device…")
                    .foregroundStyle(Brand.onGradientSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("transcript.progress")
        } else if recording.hasTranscript {
            transcriptText
        } else if recording.transcriptionStatus == .failed, let failure = recording.transcriptionFailure {
            failureView(failure)
        } else {
            Button("Transcribe") { transcription.transcribe(recording) }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("transcript.start")
        }
    }

    @ViewBuilder
    private var transcriptText: some View {
        let segments = recording.transcriptSegments
        if recording.isTranscriptEdited || segments.isEmpty {
            // Edited text no longer lines up with the word timings, so it is shown as plain text.
            Text(recording.transcriptText ?? "")
                .font(.body)
                .textSelection(.enabled)
                .accessibilityIdentifier("transcript.text")
        } else {
            let lines = TranscriptLine.lines(
                from: segments,
                separator: TranscriptLine.separator(forLocaleIdentifier: recording.transcriptLocaleIdentifier)
            )
            let current = lines.last { $0.start <= model.currentTime + 0.05 }?.id
            VStack(alignment: .leading, spacing: Brand.Spacing.small) {
                ForEach(lines) { line in
                    Button {
                        model.seek(to: line.start)
                    } label: {
                        Text(line.text)
                            .font(.body.weight(line.id == current && model.isPlaying ? .semibold : .regular))
                            .foregroundStyle(line.id == current && model.isPlaying ? Brand.onGradient : Brand.onGradientSecondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Jumps to \(DurationFormat.clock(line.start))")
                }
            }
            .accessibilityIdentifier("transcript.lines")
        }
    }

    private func failureView(_ failure: TranscriptionFailure) -> some View {
        VStack(alignment: .leading, spacing: Brand.Spacing.small) {
            Label(failure.message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .symbolRenderingMode(.multicolor)
                .accessibilityIdentifier("transcript.error")
            HStack {
                if failure == .notAuthorized {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .buttonStyle(.bordered)
                }
                Button("Try again") { transcription.transcribe(recording) }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("transcript.retry")
            }
        }
    }

    private func restoreOriginal() {
        do {
            try repository.restoreOriginalTranscript(recording)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Edit the text of a transcript. Saves only on request.
private struct TranscriptEditor: View {
    @State var text: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    init(text: String, onSave: @escaping (String) -> Void) {
        _text = State(initialValue: text)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .padding(.horizontal)
                .accessibilityIdentifier("transcript.editor")
                .navigationTitle("Edit transcript")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { onSave(text) }
                            .accessibilityIdentifier("transcript.save")
                    }
                }
        }
    }
}
