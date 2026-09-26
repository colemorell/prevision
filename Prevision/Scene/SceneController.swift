import RealityKit
import SwiftUI
import Combine
import simd

@MainActor
final class SceneController: ObservableObject {
    @Published var placedItems: [Entity] = []
    @Published var notes: [Note] = []
    @Published var armedItem: FurnitureItem? = nil
    @Published var cameraDistance: Float = 4
    @Published var cameraYaw: Float = 0
    @Published var cameraPitch: Float = 0.3

    let rootAnchor = AnchorEntity()

    func setup() async {
        do {
            let apartment = try await RoomScene.loadApartment()
            rootAnchor.addChild(apartment)
            RoomScene.addLighting(to: rootAnchor)
        } catch {
        }
    }

    func arm(_ item: FurnitureItem) {
        armedItem = item
    }

    func place(at worldPoint: SIMD3<Float>) async {
        guard let item = armedItem else { return }
        do {
            let model = try await RaycastPlacement.loadModel(for: item)
            var transform = model.transform
            transform.translation = worldPoint
            model.move(to: transform, relativeTo: model.parent, duration: 0, timingFunction: .linear)
            rootAnchor.addChild(model)
            placedItems.append(model)
        } catch {
        }
    }

    func addNote(text: String, at position: SIMD3<Float>, room: String) {
        let note = Note(text: text, position: position, room: room)
        notes.append(note)
    }

    func handleZoom(_ scale: Float) {
        cameraDistance *= scale
    }

    func handleOrbit(deltaX: Float, deltaY: Float) {
        cameraYaw += deltaX
        cameraPitch += deltaY
    }
}
