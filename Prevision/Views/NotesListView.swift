import SwiftUI

struct NotesListView: View {
    @EnvironmentObject var scene: SceneController

    var groupedNotes: [String: [Note]] {
        Dictionary(grouping: scene.notes, by: { $0.room })
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedNotes.keys.sorted(), id: \.self) { room in
                    Section(header: Text(room)) {
                        ForEach(groupedNotes[room] ?? [], id: \.self) { note in
                            Text(note.text)
                                .font(.body)
                        }
                    }
                }
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    NotesListView()
        .environmentObject(SceneController())
}
