import SwiftUI
import UIKit

/// The system share sheet. It offers Messages, AirDrop, Mail and "Save to Files" for the given files.
struct ActivityView: UIViewControllerRepresentable {
    let items: [URL]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Files ready to be shared. Identifiable so a sheet can be driven by it.
struct ShareItems: Identifiable {
    let id = UUID()
    let urls: [URL]
}

/// What the share menu offers. The same choices are used for one note and for a selection.
enum ShareChoice: CaseIterable, Identifiable {
    case audio
    case transcriptText
    case transcriptMarkdown
    case audioAndTranscript

    var id: Self { self }

    var content: ExportContent {
        switch self {
        case .audio: .audio
        case .transcriptText: .transcriptText
        case .transcriptMarkdown: .transcriptMarkdown
        case .audioAndTranscript: [.audio, .transcriptMarkdown]
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .audio: "Audio (.m4a)"
        case .transcriptText: "Transcript (.txt)"
        case .transcriptMarkdown: "Transcript (.md)"
        case .audioAndTranscript: "Audio and transcript"
        }
    }

    var symbol: String {
        switch self {
        case .audio: "waveform"
        case .transcriptText, .transcriptMarkdown: "doc.text"
        case .audioAndTranscript: "square.stack"
        }
    }
}

/// Builds the files off the main actor and reports either them or a message for the user.
@MainActor
@Observable
final class ShareCoordinator {
    var items: ShareItems?
    var errorMessage: String?
    private(set) var isPreparing = false

    private let exporter: RecordingExporter

    init(exporter: RecordingExporter = RecordingExporter()) {
        self.exporter = exporter
    }

    func share(_ recordings: [Recording], choice: ShareChoice, fileStore: RecordingFileStore) {
        guard !isPreparing else { return }
        let notes = recordings.map { $0.exportable(in: fileStore) }
        let content = choice.content
        let exporter = exporter
        isPreparing = true
        Task {
            defer { isPreparing = false }
            do {
                let urls = try await Task.detached { try exporter.export(notes, content: content) }.value
                if urls.isEmpty {
                    errorMessage = String(localized: "There is nothing to export yet. Transcribe the note first.")
                } else {
                    items = ShareItems(urls: urls)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

extension View {
    /// Presents the share sheet and the error alert driven by `coordinator`.
    func shareSheet(_ coordinator: ShareCoordinator) -> some View {
        @Bindable var coordinator = coordinator
        return self
            .sheet(item: $coordinator.items) { items in
                ActivityView(items: items.urls)
                    .presentationDetents([.medium, .large])
            }
            .alert("Couldn't export", isPresented: Binding(
                get: { coordinator.errorMessage != nil },
                set: { if !$0 { coordinator.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(coordinator.errorMessage ?? "")
            }
    }
}
