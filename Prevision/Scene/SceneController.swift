import RealityKit
import SwiftUI
import Combine
import simd

final class SceneRig {
    let root = Entity()
    let camera = PerspectiveCamera()
    var light: Entity?

    init() {
        camera.camera.fieldOfViewInDegrees = SceneController.horizontalFovDegrees
        camera.camera.fieldOfViewOrientation = .horizontal
        root.addChild(camera)
        if !ProcessInfo.processInfo.arguments.contains("-UITests") {
            root.addChild(Self.makeHeartbeat())
        }
    }

    private static func makeHeartbeat() -> Entity {
        let pulse = ModelEntity(mesh: .generateBox(size: 0.001), materials: [UnlitMaterial(color: .clear)])
        pulse.components.set(OpacityComponent(opacity: 0))
        let spin = FromToByAnimation<Transform>(
            from: Transform(rotation: simd_quatf(angle: 0, axis: [0, 1, 0])),
            to: Transform(rotation: simd_quatf(angle: .pi, axis: [0, 1, 0])),
            duration: 1,
            bindTarget: .transform,
            repeatMode: .repeat
        )
        if let resource = try? AnimationResource.generate(with: spin) {
            pulse.playAnimation(resource)
        }
        return pulse
    }
}

enum InteractionMode {
    case select
    case note
}

final class SceneController: ObservableObject {
    static let horizontalFovDegrees: Float = 80

    @Published private(set) var notes: [Note] = []
    @Published var armedItem: FurnitureItem?
    @Published var mode: InteractionMode = .select
    @Published private(set) var isLoaded = false
    @Published var loadError: String?
    @Published var pendingNotePoint: SIMD3<Float>?
    @Published var pendingNoteFromClient = false
    @Published private(set) var hasSelection = false
    @Published private(set) var revision = 0
    @Published private(set) var design: Design?

    var onDesignChange: ((Design) -> Void)?

    let designer = SceneRig()
    let client = SceneRig()
    let outer = SceneRig()

    private var rigs: [SceneRig] { [designer, client, outer] }

    private var target = SIMD3<Float>(0, 0, 0)
    private var distance: Float = 14
    private var yaw: Float = 0
    private var pitch: Float = 0.95
    private var homeDistance: Float = 14
    private var minDistance: Float = 1.5
    private var maxDistance: Float = 40

    private var placed: [PlacedItem] = []
    private var noteEntities: [[Entity]] = []
    private var prototypes: [String: Entity] = [:]
    private var selectedIndex: Int? {
        didSet {
            updateSelectionRing()
            hasSelection = selectedIndex != nil
        }
    }
    private let selectionRing = SceneController.makeSelectionRing()
    private var setupTask: Task<Void, Never>?

    private struct PlacedItem {
        let id: UUID
        let itemID: String
        let copies: [Entity]
        var position: SIMD3<Float>
        var yaw: Float
    }

    func preload(library: FurnitureLibrary) {
        guard setupTask == nil else { return }
        setupTask = Task {
            await loadEnvironment()
            for item in library.items {
                _ = try? await prototype(for: item)
            }
        }
    }

    func open(_ design: Design, library: FurnitureLibrary) async {
        preload(library: library)
        await setupTask?.value
        clearDesign()
        self.design = design
        for placement in design.placements {
            guard let item = library.item(withID: placement.itemID) else { continue }
            await spawn(item, id: placement.id, at: placement.position, yaw: placement.yaw, animated: false)
        }
        for note in design.notes {
            addNoteEntity(note)
        }
        notes = design.notes
        selectedIndex = nil
        resetCamera()
    }

    func close() {
        persist()
        clearDesign()
        design = nil
    }

    func arm(_ item: FurnitureItem) {
        withAnimation(Brand.Motion.standard) {
            armedItem = armedItem?.id == item.id ? nil : item
            mode = .select
        }
    }

    func toggleNoteMode() {
        withAnimation(Brand.Motion.standard) {
            mode = mode == .note ? .select : .note
            armedItem = nil
        }
    }

    func handleTap(at location: CGPoint, viewSize: CGSize) {
        guard let ray = ray(for: designer, at: location, viewSize: viewSize) else { return }
        switch mode {
        case .note:
            pendingNoteFromClient = false
            pendingNotePoint = ray.floorPoint
            mode = .select
        case .select:
            if let item = armedItem, let point = ray.floorPoint {
                armedItem = nil
                Task { await spawn(item, id: UUID(), at: point, yaw: 0, animated: true) }
            } else {
                selectedIndex = hitIndex(for: ray)
            }
        }
    }

    func handleDrop(_ item: FurnitureItem, at location: CGPoint, viewSize: CGSize) -> Bool {
        guard let point = ray(for: designer, at: location, viewSize: viewSize)?.floorPoint else { return false }
        armedItem = nil
        Task { await spawn(item, id: UUID(), at: point, yaw: 0, animated: true) }
        return true
    }

    func handleClientTap(at location: CGPoint, viewSize: CGSize) {
        guard design != nil, pendingNotePoint == nil,
              let point = ray(for: outer, at: location, viewSize: viewSize)?.floorPoint else { return }
        pendingNoteFromClient = true
        pendingNotePoint = point
    }

    func rotateSelected(by radians: Float) {
        guard let index = selectedIndex, placed.indices.contains(index) else { return }
        placed[index].yaw += radians
        let orientation = simd_quatf(angle: placed[index].yaw, axis: [0, 1, 0])
        placed[index].copies.forEach { $0.orientation = orientation }
        revision &+= 1
    }

    func finishRotation() {
        persist()
    }

    func removeSelected() {
        guard let index = selectedIndex, placed.indices.contains(index) else { return }
        placed.remove(at: index).copies.forEach { $0.removeFromParent() }
        selectedIndex = nil
        revision &+= 1
        persist()
    }

    func commitNote(text: String, room: String) {
        guard let point = pendingNotePoint else { return }
        pendingNotePoint = nil
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let note = Note(text: trimmed, position: point, room: room)
        notes.append(note)
        addNoteEntity(note)
        revision &+= 1
        persist()
    }

    func zoom(by factor: Float) {
        distance = min(max(distance / factor, minDistance), maxDistance)
        updateCameras()
    }

    func orbit(deltaX: Float, deltaY: Float) {
        yaw -= deltaX * 0.008
        pitch = min(max(pitch + deltaY * 0.006, 0.1), 1.45)
        updateCameras()
    }

    func resetCamera() {
        yaw = 0
        pitch = 0.95
        distance = homeDistance
        updateCameras()
    }

    private func loadEnvironment() async {
        do {
            let apartment = try await RoomScene.loadApartment()
            let bounds = apartment.visualBounds(relativeTo: nil)
            add(apartment)
            for rig in rigs {
                RoomScene.addLighting(to: rig.root)
                rig.light = await Lighting.apply(to: rig.root)
            }
            let halfWidth = max(bounds.extents.x, bounds.extents.z) / 2
            homeDistance = min(max(halfWidth / tan(Self.horizontalFovDegrees * .pi / 360) * 1.35, 6), 30)
            maxDistance = max(homeDistance * 2, 20)
            isLoaded = true
        } catch {
            loadError = error.localizedDescription
        }
        resetCamera()
    }

    private func prototype(for item: FurnitureItem) async throws -> Entity {
        if let cached = prototypes[item.id] { return cached }
        let model = try await RaycastPlacement.loadModel(for: item)
        prototypes[item.id] = model
        return model
    }

    private func spawn(_ item: FurnitureItem, id: UUID, at point: SIMD3<Float>, yaw: Float, animated: Bool) async {
        do {
            let model = try await prototype(for: item).clone(recursive: true)
            model.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
            model.position = animated ? point + SIMD3<Float>(0, 0.4, 0) : point
            let copies = add(model)
            if animated {
                for entity in copies {
                    var landed = entity.transform
                    landed.translation = point
                    entity.move(to: landed, relativeTo: entity.parent, duration: Brand.Motion.placementDuration, timingFunction: .easeInOut)
                }
            }
            placed.append(PlacedItem(id: id, itemID: item.id, copies: copies, position: point, yaw: yaw))
            if animated {
                selectedIndex = placed.count - 1
                refresh(for: Brand.Motion.placementDuration)
                persist()
            } else {
                revision &+= 1
            }
        } catch {
            loadError = "\(item.name): \(error.localizedDescription)"
        }
    }

    private func addNoteEntity(_ note: Note) {
        let pin = StickyNote.make(text: note.text)
        pin.position = note.position
        noteEntities.append(add(pin))
    }

    private func clearDesign() {
        placed.forEach { $0.copies.forEach { $0.removeFromParent() } }
        noteEntities.forEach { $0.forEach { $0.removeFromParent() } }
        placed = []
        noteEntities = []
        notes = []
        selectedIndex = nil
        armedItem = nil
        pendingNotePoint = nil
        mode = .select
        revision &+= 1
    }

    private func persist() {
        guard var design else { return }
        design.placements = placed.map { Placement(id: $0.id, itemID: $0.itemID, position: $0.position, yaw: $0.yaw) }
        design.notes = notes
        self.design = design
        onDesignChange?(design)
    }

    @discardableResult
    private func add(_ entity: Entity) -> [Entity] {
        let copies = [entity] + rigs.dropFirst().map { _ in entity.clone(recursive: true) }
        for (rig, copy) in zip(rigs, copies) {
            rig.root.addChild(copy)
            if let light = rig.light {
                Lighting.receive(copy, light: light)
            }
        }
        return copies
    }

    private func ray(for rig: SceneRig, at location: CGPoint, viewSize: CGSize) -> Ray? {
        RaycastPlacement.ray(tap: location, viewSize: viewSize, camera: rig.camera, horizontalFovDegrees: Self.horizontalFovDegrees)
    }

    private func hitIndex(for ray: Ray) -> Int? {
        placed.indices
            .compactMap { index in ray.distance(to: placed[index].copies[0].visualBounds(relativeTo: nil)).map { (index, $0) } }
            .min { $0.1 < $1.1 }?
            .0
    }

    private func updateSelectionRing() {
        guard let index = selectedIndex, placed.indices.contains(index) else {
            selectionRing.removeFromParent()
            revision &+= 1
            return
        }
        let item = placed[index].copies[0]
        let extents = item.visualBounds(relativeTo: item).extents
        let radius = max(extents.x, extents.z) / 2 + 0.15
        selectionRing.scale = SIMD3<Float>(radius, 1, radius)
        selectionRing.position = [0, 0.01, 0]
        item.addChild(selectionRing)
        revision &+= 1
    }

    private func updateCameras() {
        let offset = SIMD3<Float>(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw)) * distance
        rigs.forEach { $0.camera.look(at: target, from: target + offset, relativeTo: nil) }
        revision &+= 1
    }

    private func refresh(for duration: TimeInterval) {
        Task {
            let frames = Int(duration * 60) + 2
            for _ in 0..<frames {
                revision &+= 1
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private static func makeSelectionRing() -> Entity {
        let accent = UIColor(named: "AccentColor") ?? .tintColor
        var material = UnlitMaterial(color: accent.withAlphaComponent(0.45))
        material.blending = .transparent(opacity: 0.45)
        return ModelEntity(mesh: .generateCylinder(height: 0.01, radius: 1), materials: [material])
    }
}
