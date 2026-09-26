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
    @State private var showLight = false
    @State private var roomFrame: CGRect = .zero
    @State private var poolDrag: PoolDrag?

    var body: some View {
        NavigationStack {
            workspace
                .coordinateSpace(.named(Self.dragSpace))
                .navigationTitle(scene.design?.name ?? "")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
        }
        .sheet(isPresented: $showNotes) { NotesListView() }
        .alert(notePromptTitle, isPresented: notePromptBinding) {
            TextField("Note", text: $noteText)
            TextField("Room", text: $noteRoom)
            Button("Add") {
                scene.commitNote(text: noteText, room: noteRoom)
                noteText = ""
            }
            Button("Cancel", role: .cancel) { scene.pendingNotePoint = nil }
        }
        .modifier(DesignerFeedback(scene: scene, dragID: poolDrag?.item.id))
        .task(id: scene.lightLevel) {
            try? await Task.sleep(for: .milliseconds(500))
            if !Task.isCancelled { scene.saveLighting() }
        }
    }

    private var notePromptTitle: String {
        scene.pendingNoteFromClient ? "Client tapped here. Add a note?" : "Add a note here?"
    }

    private var workspace: some View {
        GeometryReader { geo in
            let isWide = geo.size.width > 560
            let layout = isWide ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
            layout {
                room
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.dragSpace)) } action: { roomFrame = $0 }
                AssetPoolView(axis: isWide ? .vertical : .horizontal, dragSpace: .named(Self.dragSpace), onDragChanged: poolDragChanged, onDragEnded: poolDragEnded)
                    .frame(width: isWide ? 180 : nil, height: isWide ? nil : 170)
            }
            .overlay(alignment: .topLeading) { dragCard }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Designs", systemImage: "chevron.backward", action: onClose)
                .tint(.primary)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button("Light", systemImage: "sun.max") {
                withAnimation(Brand.Motion.standard) { showLight.toggle() }
            }
            .symbolVariant(showLight ? .fill : .none)
            .tint(.primary)
            Menu("More", systemImage: "ellipsis") {
                Button(scene.mode == .note ? "Cancel Note" : "Add Note", systemImage: "note.text.badge.plus") { scene.toggleNoteMode() }
                Button("Notes", systemImage: "list.bullet.rectangle") { showNotes = true }
                Button("Recenter", systemImage: "scope") { scene.resetCamera() }
            }
            .tint(.primary)
        }
    }

    private var room: some View {
        GeometryReader { geo in
            ZStack {
                RealityView { content in
                    content.camera = .virtual
                    content.add(scene.designer.root)
                } update: { content in
                    _ = scene.revision
                    if scene.designer.root.scene == nil { content.add(scene.designer.root) }
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
                .accessibilityLabel("Room")
                .accessibilityHint("Drag to orbit, pinch to zoom. Long press a piece to edit or delete it.")

                RoundedRectangle(cornerRadius: Brand.Radius.card)
                    .strokeBorder(Brand.cta, lineWidth: 3)
                    .padding(Brand.Spacing.xs)
                    .opacity(isDropTargeted ? 1 : 0)
                    .allowsHitTesting(false)
                    .animation(Brand.Motion.standard, value: isDropTargeted)

                if showLight {
                    LightSlider(value: lightBinding)
                        .padding(.leading, Brand.Spacing.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }

                if let anchor = scene.menuAnchor(viewSize: geo.size) {
                    pieceMenu
                        .position(x: anchor.x, y: max(anchor.y - 36, 32))
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }

                VStack {
                    if !scene.isLoaded {
                        ProgressView("Loading room…")
                            .font(Brand.Typography.caption)
                            .overlayLabel()
                            .padding(.top, Brand.Spacing.m)
                    }
                    if let error = scene.loadError {
                        Text(error)
                            .font(Brand.Typography.caption)
                            .overlayLabel()
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
                Button("Edit", systemImage: "square.and.pencil") { scene.editMenuItem() }
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
            Text("Drag to move · Twist to rotate · Pinch to resize")
                .font(Brand.Typography.caption)
                .overlayLabel()
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

    static let dragSpace = "designer"

    @ViewBuilder
    private var dragCard: some View {
        if let poolDrag, !roomFrame.contains(poolDrag.location) {
            Group {
                if let thumbnail = library.thumbnails[poolDrag.item.id] {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .padding(Brand.Spacing.s)
                } else {
                    Image(systemName: "cube")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 88, height: 88)
            .glassEffect(.regular, in: .rect(cornerRadius: Brand.Radius.control))
            .position(poolDrag.location)
            .allowsHitTesting(false)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }

    private func poolDragChanged(_ item: FurnitureItem, _ location: CGPoint) {
        if poolDrag == nil {
            scene.beginDrag(item)
        }
        poolDrag = PoolDrag(item: item, location: location)
        let inside = roomFrame.contains(location)
        if isDropTargeted != inside { isDropTargeted = inside }
        if inside {
            scene.updateGhost(at: roomPoint(location), viewSize: roomFrame.size)
        } else {
            scene.hideGhost()
        }
    }

    private func poolDragEnded(_ item: FurnitureItem, _ location: CGPoint?) {
        guard poolDrag != nil else { return }
        poolDrag = nil
        isDropTargeted = false
        if let location, roomFrame.contains(location) {
            scene.handleDrop(item, at: roomPoint(location), viewSize: roomFrame.size)
        } else {
            scene.endDrag()
        }
    }

    private func roomPoint(_ location: CGPoint) -> CGPoint {
        CGPoint(x: location.x - roomFrame.minX, y: location.y - roomFrame.minY)
    }

    private var lightBinding: Binding<Double> {
        Binding(
            get: { Double(scene.lightLevel) },
            set: { scene.setLightLevel(Float($0), persisting: false) }
        )
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
                    scene.dragEditing(from: value.startLocation, to: value.location, viewSize: size)
                } else {
                    let dx = value.translation.width - lastDrag.width
                    let dy = value.translation.height - lastDrag.height
                    scene.orbit(deltaX: Float(dx), deltaY: Float(dy))
                    lastDrag = value.translation
                }
            }
            .onEnded { _ in
                lastDrag = .zero
                scene.endDragEditing()
            }
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
                let factor = Float(value.magnification / lastMagnification)
                if scene.isEditing {
                    scene.scaleEditing(by: factor)
                } else {
                    scene.zoom(by: factor)
                }
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

private struct DesignerFeedback: ViewModifier {
    @ObservedObject var scene: SceneController
    let dragID: String?

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(.selection, trigger: scene.menuIndex) { (_: Int?, new: Int?) in new != nil }
            .sensoryFeedback(.success, trigger: scene.commits)
            .sensoryFeedback(.impact(weight: .medium), trigger: dragID) { (old: String?, new: String?) in old == nil && new != nil }
            .sensoryFeedback(.impact(weight: .light), trigger: scene.editingIndex) { (old: Int?, new: Int?) in old == nil && new != nil }
    }
}

private struct PoolDrag: Equatable {
    let item: FurnitureItem
    var location: CGPoint
}
