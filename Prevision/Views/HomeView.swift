import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: DesignStore
    let onOpen: (Design) -> Void

    @State private var renamingDesign: Design?
    @State private var renameText: String = ""
    @State private var pendingDeleteDesign: Design?
    @State private var showSettings = false
    @State private var isNaming = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            Group {
                if store.designs.isEmpty {
                    ScrollView {
                        ContentUnavailableView(
                            "No Designs Yet",
                            systemImage: "square.3.layers.3d",
                            description: Text("Create a design to start placing furniture in the room.")
                        )
                        .containerRelativeFrame(.vertical)
                    }
                } else {
                    List {
                        ForEach(store.designs) { design in
                            designRow(design)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Designs")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape") { showSettings = true }
                        .tint(.primary)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New Design", systemImage: "plus", action: beginNewDesign)
                        .buttonStyle(.glassProminent)
                        .tint(Brand.cta)
                        .foregroundStyle(.white)
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .alert("New Design", isPresented: $isNaming) {
                TextField(store.nextDefaultName(), text: $newName)
                Button("Cancel", role: .cancel) {}
                Button("Create", action: createDesign)
            } message: {
                Text("Give this design a name.")
            }
            .alert(
                "Rename Design",
                isPresented: Binding(
                    get: { renamingDesign != nil },
                    set: { if !$0 { renamingDesign = nil } }
                )
            ) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) {
                    renamingDesign = nil
                }
                Button("Save") {
                    if let design = renamingDesign {
                        store.rename(design.id, to: renameText)
                    }
                    renamingDesign = nil
                }
            }
            .confirmationDialog(
                "Delete this design?",
                isPresented: Binding(
                    get: { pendingDeleteDesign != nil },
                    set: { if !$0 { pendingDeleteDesign = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let design = pendingDeleteDesign {
                        delete(design)
                    }
                    pendingDeleteDesign = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteDesign = nil
                }
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    private func beginNewDesign() {
        newName = ""
        isNaming = true
    }

    private func createDesign() {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let design = store.create(named: trimmed.isEmpty ? store.nextDefaultName() : trimmed)
        onOpen(design)
    }

    private func delete(_ design: Design) {
        withAnimation(Brand.Motion.standard) {
            store.delete(design.id)
        }
    }

    private func designRow(_ design: Design) -> some View {
        Button {
            onOpen(design)
        } label: {
            VStack(alignment: .leading, spacing: Brand.Spacing.xs) {
                Text(design.name)
                    .font(Brand.Typography.label)
                    .foregroundStyle(.primary)

                Text("Edited \(design.updatedAt, format: .relative(presentation: .named))")
                    .font(Brand.Typography.caption)
                    .foregroundStyle(.secondary)

                Text("^[\(design.placements.count) piece](inflect: true) · ^[\(design.notes.count) note](inflect: true)")
                    .font(Brand.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, Brand.Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Delete", systemImage: "trash", role: .destructive) {
                delete(design)
            }
        }
        .contextMenu {
            Button("Rename", systemImage: "square.and.pencil") {
                beginRename(design)
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                pendingDeleteDesign = design
            }
        }
    }

    private func beginRename(_ design: Design) {
        renameText = design.name
        renamingDesign = design
    }
}

#Preview {
    HomeView(onOpen: { _ in })
        .environmentObject(DesignStore())
}
