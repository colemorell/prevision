import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: DesignStore
    let onOpen: (Design) -> Void

    @State private var renamingDesign: Design?
    @State private var renameText: String = ""
    @State private var pendingDeleteDesign: Design?
    @State private var showSettings = false

    private let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 420), spacing: Brand.Spacing.m)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                if store.designs.isEmpty {
                    ContentUnavailableView(
                        "No Designs Yet",
                        systemImage: "square.3.layers.3d",
                        description: Text("Create a design to start placing furniture in the apartment.")
                    )
                    .containerRelativeFrame(.vertical)
                } else {
                    LazyVGrid(columns: columns, spacing: Brand.Spacing.m) {
                        ForEach(store.designs) { design in
                            designCard(design)
                        }
                    }
                    .padding(Brand.Spacing.m)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) {
                newDesignButton
                    .padding(Brand.Spacing.m)
            }
            .background(Brand.canvas)
            .navigationTitle("Designs")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { showSettings = true }
                        .tint(.primary)
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
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
                        withAnimation(Brand.Motion.standard) {
                            store.delete(design.id)
                        }
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

    private var newDesignButton: some View {
        Button {
            withAnimation(Brand.Motion.standard) {
                let design = store.create(named: store.nextDefaultName())
                onOpen(design)
            }
        } label: {
            Text("New Design")
                .font(Brand.Typography.label)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .tint(Brand.cta)
        .controlSize(.large)
    }

    private func designCard(_ design: Design) -> some View {
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

                Text("\(design.placements.count) pieces · \(design.notes.count) notes")
                    .font(Brand.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(Brand.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                beginRename(design)
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button(role: .destructive) {
                pendingDeleteDesign = design
            } label: {
                Label("Delete", systemImage: "trash")
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
