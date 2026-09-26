import RealityKit
import SwiftUI
import Combine
import simd

final class SceneRig {
    let root = Entity()
    let camera = PerspectiveCamera()
    var light: Entity?
    var directionalLights: [(light: DirectionalLight, base: Float)] = []
    private weak var owner: Entity?
    var subscription: EventSubscription?

    func attach(to holder: Entity) {
        owner = holder
        if root.parent !== holder { holder.addChild(root) }
    }

    func keepAttached(to holder: Entity) {
        if owner === holder, root.parent !== holder { holder.addChild(root) }
    }

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
    @Published private(set) var editingIndex: Int?
    @Published private(set) var menuIndex: Int?
    @Published private(set) var commits = 0
    @Published private(set) var revision = 0
    @Published private(set) var design: Design?
    @Published private(set) var lightLevel: Float = 0.5

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
    private(set) var draggingItem: FurnitureItem?
    private var ghost: Entity?
    private var ghostItemID: String?
    private var floorArea: (min: SIMD2<Float>, max: SIMD2<Float>)?
    private var grabStart: CGPoint?
    private var grabOffset = SIMD3<Float>.zero
    private let selectionRing = SceneController.makeSelectionRing()

    var isEditing: Bool { editingIndex != nil }
    private var setupTask: Task<Void, Never>?

    private struct PlacedItem {
        let id: UUID
        let itemID: String
        let copies: [Entity]
        var position: SIMD3<Float>
        var yaw: Float
        var scale: Float
    }

    func preload(library: FurnitureLibrary) {
        guard setupTask == nil else { return }
        let items = library.items
        setupTask = Task { await loadEnvironment() }
        Task {
            for item in items {
                _ = try? await prototype(for: item)
            }
        }
    }

    func open(_ design: Design, library: FurnitureLibrary) async {
        preload(library: library)
        clearDesign()
        self.design = design
        await setupTask?.value
        guard self.design?.id == design.id else { return }
        for placement in design.placements {
            guard let item = library.item(withID: placement.itemID) else { continue }
            await spawn(item, id: placement.id, at: placement.position, yaw: placement.yaw, scale: placement.scale, animated: false)
        }
        for note in design.notes {
            addNoteEntity(note)
        }
        notes = design.notes
        setLightLevel(design.lightLevel ?? 0.5, persisting: false)
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
        if menuIndex != nil {
            setMenu(nil)
            return
        }
        if isEditing {
            if let point = ray.floorPoint { moveEditing(to: point) }
            return
        }
        switch mode {
        case .note:
            pendingNoteFromClient = false
            pendingNotePoint = ray.floorPoint
            mode = .select
        case .select:
            if let item = armedItem, let point = ray.floorPoint {
                armedItem = nil
                Task { await placeForEditing(item, at: point) }
            }
        }
    }

    func handleLongPress(at location: CGPoint, viewSize: CGSize) {
        guard !isEditing, let ray = ray(for: designer, at: location, viewSize: viewSize) else { return }
        setMenu(hitIndex(for: ray))
    }

    func beginDrag(_ item: FurnitureItem) {
        draggingItem = item
        armedItem = nil
        if menuIndex != nil { setMenu(nil) }
    }

    func endDrag() {
        draggingItem = nil
        hideGhost()
    }

    func updateGhost(at location: CGPoint, viewSize: CGSize) {
        guard let item = draggingItem, let floor = floorPoint(for: designer, at: location, viewSize: viewSize) else { return }
        let point = clamped(floor, itemID: item.id, yaw: 0)
        if ghostItemID != item.id {
            hideGhost()
            guard let prototype = prototypes[item.id] else {
                Task { _ = try? await self.prototype(for: item) }
                return
            }
            let preview = prototype.clone(recursive: true)
            preview.components.set(OpacityComponent(opacity: 0.4))
            designer.root.addChild(preview)
            ghost = preview
            ghostItemID = item.id
        }
        ghost?.position = point
        revision &+= 1
    }

    func hideGhost() {
        ghost?.removeFromParent()
        ghost = nil
        ghostItemID = nil
        revision &+= 1
    }

    func handleDrop(_ item: FurnitureItem, at location: CGPoint, viewSize: CGSize) {
        let point = ghost?.position ?? floorPoint(for: designer, at: location, viewSize: viewSize)
        endDrag()
        guard let point else { return }
        Task { await placeForEditing(item, at: point) }
    }

    func handleClientTap(at location: CGPoint, viewSize: CGSize) {
        guard design != nil, pendingNotePoint == nil,
              let floor = floorPoint(for: outer, at: location, viewSize: viewSize) else { return }
        let point = clamped(floor)
        pendingNoteFromClient = true
        pendingNotePoint = point
    }

    func editMenuItem() {
        guard let index = menuIndex else { return }
        setMenu(nil)
        setEditing(index)
    }

    func deleteMenuItem() {
        guard let index = menuIndex, placed.indices.contains(index) else { return }
        setMenu(nil)
        placed.remove(at: index).copies.forEach { $0.removeFromParent() }
        revision &+= 1
        persist()
    }

    func moveEditing(to target: SIMD3<Float>) {
        guard let index = editingIndex, placed.indices.contains(index) else { return }
        let point = clamped(target, itemID: placed[index].itemID, yaw: placed[index].yaw, scale: placed[index].scale)
        placed[index].position = point
        applyTransform(index)
    }

    func dragEditing(from start: CGPoint, to location: CGPoint, viewSize: CGSize) {
        guard let index = editingIndex, placed.indices.contains(index) else { return }
        if grabStart != start {
            guard let origin = floorPoint(for: designer, at: start, viewSize: viewSize) else { return }
            grabStart = start
            grabOffset = placed[index].position - origin
        }
        guard let point = floorPoint(for: designer, at: location, viewSize: viewSize) else { return }
        moveEditing(to: point + grabOffset)
    }

    func endDragEditing() {
        grabStart = nil
    }

    func rotateEditing(by radians: Float, animated: Bool = false) {
        guard let index = editingIndex, placed.indices.contains(index) else { return }
        placed[index].yaw += radians
        placed[index].position = clamped(placed[index].position, itemID: placed[index].itemID, yaw: placed[index].yaw, scale: placed[index].scale)
        let orientation = simd_quatf(angle: placed[index].yaw, axis: [0, 1, 0])
        for entity in placed[index].copies {
            var turned = entity.transform
            turned.rotation = orientation
            turned.translation = placed[index].position
            if animated {
                entity.move(to: turned, relativeTo: entity.parent, duration: 0.25, timingFunction: .easeInOut)
            } else {
                entity.transform = turned
            }
        }
        animated ? refresh(for: 0.25) : (revision &+= 1)
    }

    func scaleEditing(by factor: Float) {
        guard let index = editingIndex, placed.indices.contains(index) else { return }
        placed[index].scale = min(max(placed[index].scale * factor, 0.3), 3)
        placed[index].position = clamped(placed[index].position, itemID: placed[index].itemID, yaw: placed[index].yaw, scale: placed[index].scale)
        applyTransform(index)
        updateSelectionRing()
    }

    func setLightLevel(_ level: Float, persisting: Bool = true) {
        lightLevel = min(max(level, 0), 1)
        let multiplier = pow(2, (lightLevel - 0.5) * 4)
        for rig in rigs {
            for entry in rig.directionalLights {
                entry.light.light.intensity = entry.base * multiplier
            }
            if var component = rig.light?.components[ImageBasedLightComponent.self] {
                component.intensityExponent = 1 + (lightLevel - 0.5) * 4
                rig.light?.components.set(component)
            }
        }
        revision &+= 1
        if persisting { persist() }
    }

    func saveLighting() {
        guard let design, (design.lightLevel ?? 0.5) != lightLevel else { return }
        persist()
    }

    private func applyTransform(_ index: Int) {
        let item = placed[index]
        let transform = Transform(
            scale: SIMD3(repeating: item.scale),
            rotation: simd_quatf(angle: item.yaw, axis: [0, 1, 0]),
            translation: item.position
        )
        for entity in item.copies {
            entity.stopAllAnimations()
            entity.transform = transform
        }
        revision &+= 1
    }

    func commitEditing() {
        guard isEditing else { return }
        setEditing(nil)
        commits &+= 1
        persist()
    }

    func menuAnchor(viewSize: CGSize) -> CGPoint? {
        guard let index = menuIndex, placed.indices.contains(index) else { return nil }
        let bounds = placed[index].copies[0].visualBounds(relativeTo: nil)
        return project(SIMD3<Float>(bounds.center.x, bounds.max.y, bounds.center.z), viewSize: viewSize)
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

    func pan(deltaX: Float, deltaY: Float) {
        let scale = distance * 0.0016
        let right = SIMD3<Float>(cos(yaw), 0, -sin(yaw))
        let forward = SIMD3<Float>(-sin(yaw), 0, -cos(yaw))
        var next = target - right * deltaX * scale + forward * deltaY * scale
        if let area = floorArea {
            next.x = min(max(next.x, area.min.x), area.max.x)
            next.z = min(max(next.z, area.min.y), area.max.y)
        }
        target = next
        updateCameras()
    }

    func orbit(deltaX: Float, deltaY: Float) {
        yaw -= deltaX * 0.008
        pitch = min(max(pitch + deltaY * 0.006, 0.1), 1.45)
        updateCameras()
    }

    func retryLoading(library: FurnitureLibrary) {
        guard !isLoaded else { return }
        if loadError != nil {
            setupTask?.cancel()
            setupTask = nil
            loadError = nil
            let pending = design
            preload(library: library)
            if let pending { Task { await open(pending, library: library) } }
        }
        revision &+= 1
    }

    func resetCamera() {
        target = .zero
        yaw = 0
        pitch = 0.95
        distance = homeDistance
        updateCameras()
    }

    private func loadEnvironment() async {
        do {
            let apartment = try await RoomScene.loadApartment()
            for rig in rigs {
                rig.directionalLights = RoomScene.addLighting(to: rig.root).map { ($0, $0.light.intensity) }
                rig.light = await Lighting.apply(to: rig.root)
            }
            let bounds = apartment.visualBounds(relativeTo: nil)
            let floor = apartment.findEntity(named: RoomScene.floorName)?.visualBounds(relativeTo: nil) ?? bounds
            let inset: Float = 0.1
            floorArea = (SIMD2(floor.min.x + inset, floor.min.z + inset), SIMD2(floor.max.x - inset, floor.max.z - inset))
            add(apartment)
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

    private func spawn(_ item: FurnitureItem, id: UUID, at point: SIMD3<Float>, yaw: Float, scale: Float = 1, animated: Bool) async {
        do {
            let model = try await prototype(for: item).clone(recursive: true)
            model.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
            model.scale = SIMD3(repeating: scale)
            model.position = animated ? point + SIMD3<Float>(0, 0.4, 0) : point
            let copies = add(model)
            if animated {
                for entity in copies {
                    var landed = entity.transform
                    landed.translation = point
                    entity.move(to: landed, relativeTo: entity.parent, duration: Brand.Motion.placementDuration, timingFunction: .easeInOut)
                }
            }
            placed.append(PlacedItem(id: id, itemID: item.id, copies: copies, position: point, yaw: yaw, scale: scale))
            if animated {
                refresh(for: Brand.Motion.placementDuration)
            } else {
                revision &+= 1
            }
        } catch {
            loadError = "\(item.name): \(error.localizedDescription)"
        }
    }

    private func placeForEditing(_ item: FurnitureItem, at target: SIMD3<Float>) async {
        if isEditing { commitEditing() }
        _ = try? await prototype(for: item)
        let point = clamped(target, itemID: item.id, yaw: 0)
        let before = placed.count
        await spawn(item, id: UUID(), at: point, yaw: 0, animated: true)
        if placed.count > before {
            setEditing(placed.count - 1)
        }
    }

    private func setEditing(_ index: Int?) {
        withAnimation(Brand.Motion.standard) { editingIndex = index }
        updateSelectionRing()
    }

    private func setMenu(_ index: Int?) {
        withAnimation(Brand.Motion.standard) { menuIndex = index }
        updateSelectionRing()
    }

    private func project(_ point: SIMD3<Float>, viewSize: CGSize) -> CGPoint? {
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }
        let view = designer.camera.transformMatrix(relativeTo: nil).inverse
        let local = view * SIMD4<Float>(point, 1)
        guard local.z < 0 else { return nil }
        let tanHalf = tan(Self.horizontalFovDegrees * .pi / 360)
        let aspect = Float(viewSize.width / viewSize.height)
        let ndcX = (local.x / -local.z) / tanHalf
        let ndcY = (local.y / -local.z) / (tanHalf / aspect)
        return CGPoint(x: CGFloat((ndcX + 1) / 2) * viewSize.width, y: CGFloat((1 - ndcY) / 2) * viewSize.height)
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
        editingIndex = nil
        menuIndex = nil
        updateSelectionRing()
        endDrag()
        armedItem = nil
        pendingNotePoint = nil
        mode = .select
        revision &+= 1
    }

    private func persist() {
        guard var design else { return }
        design.placements = placed.map { Placement(id: $0.id, itemID: $0.itemID, position: $0.position, yaw: $0.yaw, scale: $0.scale) }
        design.notes = notes
        design.lightLevel = lightLevel
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

    private func floorPoint(for rig: SceneRig, at location: CGPoint, viewSize: CGSize) -> SIMD3<Float>? {
        ray(for: rig, at: location, viewSize: viewSize)?.groundPoint
    }

    private func clamped(_ point: SIMD3<Float>, itemID: String? = nil, yaw: Float = 0, scale: Float = 1) -> SIMD3<Float> {
        guard let area = floorArea else { return point }
        var low = SIMD2<Float>.zero
        var high = SIMD2<Float>.zero
        if let itemID, let prototype = prototypes[itemID] {
            var bounds = prototype.visualBounds(relativeTo: nil)
            bounds = BoundingBox(min: bounds.min * scale, max: bounds.max * scale)
            let c = cos(yaw), s = sin(yaw)
            let corners = [
                SIMD2(bounds.min.x, bounds.min.z), SIMD2(bounds.max.x, bounds.min.z),
                SIMD2(bounds.min.x, bounds.max.z), SIMD2(bounds.max.x, bounds.max.z)
            ].map { SIMD2($0.x * c + $0.y * s, -$0.x * s + $0.y * c) }
            low = corners.reduce(corners[0]) { simd_min($0, $1) }
            high = corners.reduce(corners[0]) { simd_max($0, $1) }
        }
        func fit(_ value: Float, _ lower: Float, _ upper: Float) -> Float {
            lower <= upper ? min(max(value, lower), upper) : (lower + upper) / 2
        }
        return SIMD3(
            fit(point.x, area.min.x - low.x, area.max.x - high.x),
            point.y,
            fit(point.z, area.min.y - low.y, area.max.y - high.y)
        )
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
        guard let index = editingIndex ?? menuIndex, placed.indices.contains(index) else {
            selectionRing.removeFromParent()
            revision &+= 1
            return
        }
        let item = placed[index].copies[0]
        selectionRing.removeFromParent()
        let bounds = item.visualBounds(relativeTo: item)
        let radius = max(bounds.extents.x, bounds.extents.z) / 2 + 0.1
        selectionRing.scale = SIMD3<Float>(radius, 1, radius)
        selectionRing.position = [bounds.center.x, 0.01, bounds.center.z]
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
        var material = UnlitMaterial(color: accent.withAlphaComponent(0.3))
        material.blending = .transparent(opacity: 0.3)
        return ModelEntity(mesh: .generateCylinder(height: 0.01, radius: 1), materials: [material])
    }
}
