import SwiftUI

struct NotesListView: View {
    @EnvironmentObject var scene: SceneController
    @Environment(\.dismiss) private var dismiss

    private var groupedNotes: [String: [Note]] {
        Dictionary(grouping: scene.notes, by: \.room)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedNotes.keys.sorted(), id: \.self) { room in
                    Section(room) {
                        ForEach(groupedNotes[room] ?? []) { note in
                            Text(note.text)
                                .font(Brand.Typography.body)
                        }
                    }
                }
            }
            .overlay {
                if scene.notes.isEmpty {
                    ContentUnavailableView("No Notes", systemImage: "note.text", description: Text("Switch to Note and tap the room to pin one."))
                }
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
