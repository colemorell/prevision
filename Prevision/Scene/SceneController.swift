import RealityKit
import SwiftUI
import Combine
import simd

final class SceneRig {
    let root = Entity()
    let camera = PerspectiveCamera()

    init() {
        camera.camera.fieldOfViewInDegrees = SceneController.fovDegrees
        root.addChild(camera)
    }
}

enum InteractionMode: String, CaseIterable, Identifiable {
    case place = "Place"
    case note = "Note"
    var id: String { rawValue }
}

final class SceneController: ObservableObject {
    static let fovDegrees: Float = 60

    @Published var placedCount = 0
    @Published var notes: [Note] = []
    @Published var armedItem: FurnitureItem?
    @Published var mode: InteractionMode = .place
    @Published var isLoaded = false
    @Published var loadError: String?
    @Published var pendingNotePoint: SIMD3<Float>?

    let designer = SceneRig()
    let client = SceneRig()
    let outer = SceneRig()

    private var rigs: [SceneRig] { [designer, client, outer] }

    private var target = SIMD3<Float>(0, 1, 0)
    private var distance: Float = 12
    private var yaw: Float = .pi / 4
    private var pitch: Float = 0.9
    private var minDistance: Float = 1.5
    private var maxDistance: Float = 40

    private var placed: [[Entity]] = []
    private var selectedIndex: Int?
    private var didSetup = false

    func setup() async {
        guard !didSetup else { return }
        didSetup = true
        do {
            let apartment = try await RoomScene.loadApartment()
            let bounds = apartment.visualBounds(relativeTo: nil)
            add(apartment)

            let floorSize = SIMD2<Float>(max(bounds.extents.x, 10) * 2, max(bounds.extents.z, 10) * 2)
            designer.root.addChild(RoomScene.makeFloor(size: floorSize))
            rigs.forEach { RoomScene.addLighting(to: $0.root) }

            target = SIMD3<Float>(0, min(bounds.extents.y * 0.3, 1.2), 0)
            distance = min(max(bounds.extents.max() * 0.9, 6), 30)
            maxDistance = max(distance * 2.5, 20)
            isLoaded = true
        } catch {
            loadError = error.localizedDescription
        }
        updateCameras()
    }

    func arm(_ item: FurnitureItem) {
        armedItem = armedItem?.id == item.id ? nil : item
        mode = .place
    }

    func handleTap(at location: CGPoint, viewSize: CGSize) {
        guard let point = RaycastPlacement.floorPoint(tap: location, viewSize: viewSize, camera: designer.camera, fovDegrees: Self.fovDegrees) else { return }
        switch mode {
        case .place:
            Task { await place(at: point) }
        case .note:
            pendingNotePoint = point
        }
    }

    func place(at worldPoint: SIMD3<Float>) async {
        guard let item = armedItem else { return }
        do {
            let model = try await RaycastPlacement.loadModel(for: item)
            model.position = worldPoint + SIMD3<Float>(0, 0.4, 0)
            let copies = add(model)
            for entity in copies {
                var landed = entity.transform
                landed.translation = worldPoint
                entity.move(to: landed, relativeTo: entity.parent, duration: Brand.Motion.placementDuration, timingFunction: .easeInOut)
            }
            placed.append(copies)
            selectedIndex = placed.count - 1
            placedCount = placed.count
        } catch {
            loadError = "\(item.name): \(error.localizedDescription)"
        }
    }

    func rotateSelected(by radians: Float) {
        guard let index = selectedIndex, placed.indices.contains(index) else { return }
        let delta = simd_quatf(angle: radians, axis: [0, 1, 0])
        let orientation = delta * placed[index][0].orientation
        placed[index].forEach { $0.orientation = orientation }
    }

    func removeLast() {
        guard let last = placed.popLast() else { return }
        last.forEach { $0.removeFromParent() }
        selectedIndex = placed.isEmpty ? nil : placed.count - 1
        placedCount = placed.count
    }

    func commitNote(text: String, room: String) {
        guard let point = pendingNotePoint else { return }
        pendingNotePoint = nil
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        notes.append(Note(text: trimmed, position: point, room: room))
        let pin = Self.makePin()
        pin.position = point
        add(pin)
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

    @discardableResult
    private func add(_ entity: Entity) -> [Entity] {
        let copies = [entity] + rigs.dropFirst().map { _ in entity.clone(recursive: true) }
        zip(rigs, copies).forEach { $0.root.addChild($1) }
        return copies
    }

    private func updateCameras() {
        let offset = SIMD3<Float>(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw)) * distance
        rigs.forEach { $0.camera.look(at: target, from: target + offset, relativeTo: nil) }
    }

    private static func makePin() -> Entity {
        let pin = Entity()
        let stem = ModelEntity(mesh: .generateCylinder(height: 0.9, radius: 0.012), materials: [SimpleMaterial(color: .darkGray, isMetallic: false)])
        stem.position.y = 0.45
        let head = ModelEntity(mesh: .generateBox(width: 0.28, height: 0.22, depth: 0.02, cornerRadius: 0.02), materials: [SimpleMaterial(color: .systemYellow, isMetallic: false)])
        head.position.y = 1.0
        pin.addChild(stem)
        pin.addChild(head)
        return pin
    }
}
