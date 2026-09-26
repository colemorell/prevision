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
            GeometryReader { geo in
                if geo.size.width > 560 {
                    HStack(spacing: 0) {
                        room
                        AssetPoolView(axis: .vertical)
                            .frame(width: 180)
                    }
                } else {
                    VStack(spacing: 0) {
                        room
                        AssetPoolView(axis: .horizontal)
                            .frame(height: 170)
                    }
                }
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
        .sensoryFeedback(.selection, trigger: scene.menuIndex) { _, new in new != nil }
        .sensoryFeedback(.success, trigger: scene.commits)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Designs", systemImage: "chevron.backward", action: onClose)
                .tint(.primary)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
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
                .gesture(dragGesture(in: geo.size))
                .simultaneousGesture(zoomGesture)
                .simultaneousGesture(rotateGesture)
                .simultaneousGesture(longPressGesture(in: geo.size))
                .simultaneousGesture(
                    SpatialTapGesture().onEnded { value in
                        scene.handleTap(at: value.location, viewSize: geo.size)
                    }
                )
                .dropDestination(for: String.self) { ids, session in
                    isDropTargeted = false
                    guard let id = ids.first, let item = library.item(withID: id) else {
                        scene.endDrag()
                        return
                    }
                    scene.handleDrop(item, at: session.location, viewSize: geo.size)
                }
                .onDropSessionUpdated { session in
                    switch session.phase {
                    case .entering, .active:
                        isDropTargeted = true
                        scene.updateGhost(at: session.location, viewSize: geo.size)
                    case .exiting:
                        isDropTargeted = false
                        scene.hideGhost()
                    default:
                        isDropTargeted = false
                    }
                }
                .accessibilityLabel("Apartment")
                .accessibilityHint("Drag to orbit, pinch to zoom. Long press a piece to edit or delete it.")

                RoundedRectangle(cornerRadius: Brand.Radius.card)
                    .strokeBorder(Brand.cta, lineWidth: 3)
                    .padding(Brand.Spacing.xs)
                    .opacity(isDropTargeted ? 1 : 0)
                    .allowsHitTesting(false)
                    .animation(Brand.Motion.standard, value: isDropTargeted)

                if let anchor = scene.menuAnchor(viewSize: geo.size) {
                    pieceMenu
                        .position(x: anchor.x, y: max(anchor.y - 36, 32))
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }

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
                    if scene.isEditing {
                        editBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if capture.isRunning {
                        CameraPreviewView(session: capture.session)
                            .frame(width: 1, height: 1)
                            .opacity(0.02)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
            }
            .animation(Brand.Motion.standard, value: scene.isEditing)
            .animation(Brand.Motion.standard, value: scene.menuIndex)
        }
    }

    private var pieceMenu: some View {
        GlassEffectContainer(spacing: Brand.Spacing.s) {
            HStack(spacing: Brand.Spacing.s) {
                Button("Edit", systemImage: "pencil") { scene.editMenuItem() }
                    .tint(.primary)
                Button("Delete", systemImage: "trash", role: .destructive) { scene.deleteMenuItem() }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
        }
    }

    private var editBar: some View {
        VStack(spacing: Brand.Spacing.s) {
            Text("Drag to move · Twist to rotate")
                .font(Brand.Typography.caption)
                .foregroundStyle(.secondary)
            GlassEffectContainer(spacing: Brand.Spacing.s) {
                HStack(spacing: Brand.Spacing.s) {
                    Button("Rotate Left", systemImage: "rotate.left") { scene.rotateEditing(by: .pi / 12, animated: true) }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .tint(.primary)
                    Button("Rotate Right", systemImage: "rotate.right") { scene.rotateEditing(by: -.pi / 12, animated: true) }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .tint(.primary)
                    Button("Set") { scene.commitEditing() }
                        .font(Brand.Typography.label)
                        .buttonStyle(.glassProminent)
                        .tint(Brand.cta)
                }
                .controlSize(.large)
            }
        }
        .padding(Brand.Spacing.m)
    }

    private var notePromptBinding: Binding<Bool> {
        Binding(
            get: { scene.pendingNotePoint != nil },
            set: { if !$0 { scene.pendingNotePoint = nil } }
        )
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if scene.isEditing {
                    scene.moveEditing(toScreen: value.location, viewSize: size)
                } else {
                    let dx = value.translation.width - lastDrag.width
                    let dy = value.translation.height - lastDrag.height
                    scene.orbit(deltaX: Float(dx), deltaY: Float(dy))
                    lastDrag = value.translation
                }
            }
            .onEnded { _ in lastDrag = .zero }
    }

    private func longPressGesture(in size: CGSize) -> some Gesture {
        LongPressGesture(minimumDuration: 0.45)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onEnded { value in
                if case .second(true, let drag?) = value {
                    scene.handleLongPress(at: drag.startLocation, viewSize: size)
                }
            }
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
                scene.rotateEditing(by: -Float((value.rotation - lastRotation).radians))
                lastRotation = value.rotation
            }
            .onEnded { _ in lastRotation = .zero }
    }
}
