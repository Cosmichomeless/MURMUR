import SwiftUI

/// Edit the title and the tags of a note. Saves only on request.
struct RecordingDetailsSheet: View {
    let recording: Recording
    let repository: RecordingRepository

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var tags: [String]
    @State private var newTag = ""
    @State private var errorMessage: String?
    @FocusState private var focus: Field?

    private enum Field { case title, tag }

    init(recording: Recording, repository: RecordingRepository) {
        self.recording = recording
        self.repository = repository
        _title = State(initialValue: recording.title)
        _tags = State(initialValue: recording.tags)
    }

    /// Tags already used elsewhere that match what is being typed.
    private var suggestions: [String] {
        let typed = TagList.key(newTag.trimmingCharacters(in: .whitespaces))
        let current = Set(tags.map(TagList.key))
        return repository.allTags()
            .filter { !current.contains(TagList.key($0)) && (typed.isEmpty || TagList.key($0).contains(typed)) }
            .prefix(8)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Title", text: $title)
                        .focused($focus, equals: .title)
                        .submitLabel(.done)
                        .accessibilityIdentifier("details.title")
                }

                Section("Tags") {
                    ForEach(tags, id: \.self) { tag in
                        Label(tag, systemImage: "tag")
                    }
                    .onDelete { tags.remove(atOffsets: $0) }

                    if tags.count < TagList.maxTags {
                        TextField("Add a tag", text: $newTag)
                            .focused($focus, equals: .tag)
                            .submitLabel(.done)
                            .onSubmit(addTag)
                            .accessibilityIdentifier("details.newTag")
                    }
                }

                if !suggestions.isEmpty, tags.count < TagList.maxTags {
                    Section("Your tags") {
                        ForEach(suggestions, id: \.self) { tag in
                            Button { add(tag) } label: { Label(tag, systemImage: "plus.circle") }
                        }
                    }
                }
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .accessibilityIdentifier("details.save")
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
    }

    private func addTag() { add(newTag) }

    private func add(_ text: String) {
        tags = TagList.normalize(tags + TagList.parse(text))
        newTag = ""
    }

    private func save() {
        // A tag typed but not yet confirmed still counts.
        let finalTags = TagList.normalize(tags + TagList.parse(newTag))
        do {
            try repository.updateDetails(recording, title: title, tags: finalTags)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
