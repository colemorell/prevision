import SwiftUI
import RealityKit

struct DesignerView: View {
    @EnvironmentObject var library: FurnitureLibrary
    @EnvironmentObject var scene: SceneController
    @EnvironmentObject var capture: CaptureSessionController
    let onClose: () -> Void

    @State private var showNotes = false
    @State private var lastMagnification: CGFloat = 1
    @State private var lastDrag: CGSize = .zero
    @State private var lastRotation: Angle = .zero
    @State private var noteText = ""
    @State private var noteRoom = "Living Room"
    @State private var isDropTargeted = false

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                room
                AssetPoolView()
                    .frame(width: 180)
            }
            .navigationTitle(scene.design?.name ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .sheet(isPresented: $showNotes) { NotesListView() }
        .alert(scene.pendingNoteFromClient ? "Client tapped here. Add a note?" : "Add a note here?", isPresented: notePromptBinding) {
            TextField("Note", text: $noteText)
            TextField("Room", text: $noteRoom)
            Button("Add") {
                scene.commitNote(text: noteText, room: noteRoom)
                noteText = ""
            }
            Button("Cancel", role: .cancel) { scene.pendingNotePoint = nil }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Designs", systemImage: "chevron.backward", action: onClose)
                .tint(.primary)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if scene.hasSelection {
                Button("Remove", systemImage: "trash", role: .destructive) { scene.removeSelected() }
            }
            Button("Add Note", systemImage: "note.text.badge.plus") { scene.toggleNoteMode() }
                .symbolVariant(scene.mode == .note ? .fill : .none)
                .tint(.primary)
            Button("Notes", systemImage: "list.bullet.rectangle") { showNotes = true }
                .tint(.primary)
            Button("Recenter", systemImage: "scope") { scene.resetCamera() }
                .tint(.primary)
        }
    }

    private var room: some View {
        GeometryReader { geo in
            ZStack {
                RealityView { content in
                    content.camera = .virtual
                    content.add(scene.designer.root)
                } update: { _ in
                    _ = scene.revision
                }
                .background(Brand.canvas)
                .gesture(orbitGesture)
                .simultaneousGesture(zoomGesture)
                .simultaneousGesture(rotateGesture)
                .simultaneousGesture(
                    SpatialTapGesture().onEnded { value in
                        scene.handleTap(at: value.location, viewSize: geo.size)
                    }
                )
                .dropDestination(for: String.self) { ids, location in
                    guard let id = ids.first, let item = library.item(withID: id) else { return false }
                    return scene.handleDrop(item, at: location, viewSize: geo.size)
                } isTargeted: { isDropTargeted = $0 }

                RoundedRectangle(cornerRadius: Brand.Radius.card)
                    .strokeBorder(Brand.cta, lineWidth: 3)
                    .padding(Brand.Spacing.xs)
                    .opacity(isDropTargeted ? 1 : 0)
                    .allowsHitTesting(false)
                    .animation(Brand.Motion.standard, value: isDropTargeted)

                VStack {
                    if !scene.isLoaded {
                        ProgressView("Loading apartment…")
                            .font(Brand.Typography.caption)
                            .padding(.top, Brand.Spacing.m)
                    }
                    if let error = scene.loadError {
                        Text(error)
                            .font(Brand.Typography.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, Brand.Spacing.m)
                    }
                    Spacer()
                    if capture.isRunning {
                        HStack {
                            CameraPreviewView(session: capture.session)
                                .frame(width: 60, height: 80)
                                .clipShape(.rect(cornerRadius: Brand.Radius.control))
                                .accessibilityLabel("Camera preview")
                            Spacer()
                        }
                        .padding(Brand.Spacing.s)
                    }
                }
            }
        }
    }

    private var notePromptBinding: Binding<Bool> {
        Binding(
            get: { scene.pendingNotePoint != nil },
            set: { if !$0 { scene.pendingNotePoint = nil } }
        )
    }

    private var orbitGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let dx = value.translation.width - lastDrag.width
                let dy = value.translation.height - lastDrag.height
                scene.orbit(deltaX: Float(dx), deltaY: Float(dy))
                lastDrag = value.translation
            }
            .onEnded { _ in lastDrag = .zero }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scene.zoom(by: Float(value.magnification / lastMagnification))
                lastMagnification = value.magnification
            }
            .onEnded { _ in lastMagnification = 1 }
    }

    private var rotateGesture: some Gesture {
        RotateGesture()
            .onChanged { value in
                scene.rotateSelected(by: -Float((value.rotation - lastRotation).radians))
                lastRotation = value.rotation
            }
            .onEnded { _ in
                lastRotation = .zero
                scene.finishRotation()
            }
    }
}
