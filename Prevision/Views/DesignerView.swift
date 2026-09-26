import SwiftUI
import RealityKit

struct DesignerView: View {
    @EnvironmentObject var catalog: FurnitureCatalog
    @EnvironmentObject var scene: SceneController

    @State private var showNotes = false
    @State private var lastMagnification: CGFloat = 1
    @State private var lastDrag: CGSize = .zero
    @State private var lastRotation: Angle = .zero
    @State private var noteText = ""
    @State private var noteRoom = "Living Room"

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RealityView { content in
                    content.camera = .virtual
                    content.add(scene.designer.root)
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

                VStack {
                    HStack(spacing: Brand.Spacing.m) {
                        Picker("Mode", selection: $scene.mode.animation(Brand.Motion.standard)) {
                            ForEach(InteractionMode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                        Spacer()
                        if scene.placedCount > 0 {
                            Button("Undo", systemImage: "arrow.uturn.backward") { scene.removeLast() }
                                .labelStyle(.iconOnly)
                                .transition(.opacity)
                        }
                        Button("Notes", systemImage: "note.text") { showNotes = true }
                            .labelStyle(.iconOnly)
                    }
                    .font(Brand.Typography.title)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .padding(Brand.Spacing.m)
                    .animation(Brand.Motion.standard, value: scene.placedCount)

                    if !scene.isLoaded {
                        ProgressView("Loading apartment…")
                            .font(Brand.Typography.caption)
                    }
                    if let error = scene.loadError {
                        Text(error)
                            .font(Brand.Typography.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, Brand.Spacing.m)
                    }

                    Spacer()

                    FurnitureListView()
                }
            }
        }
        .task { await scene.setup() }
        .sheet(isPresented: $showNotes) { NotesListView() }
        .alert("Add a note here?", isPresented: notePromptBinding) {
            TextField("Note", text: $noteText)
            TextField("Room", text: $noteRoom)
            Button("Add") {
                scene.commitNote(text: noteText, room: noteRoom)
                noteText = ""
            }
            Button("Cancel", role: .cancel) { scene.pendingNotePoint = nil }
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
            .onEnded { _ in lastRotation = .zero }
    }
}
