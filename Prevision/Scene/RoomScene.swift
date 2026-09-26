import RealityKit
import Foundation
import simd

enum RoomScene {
    static let environmentName = "Simple_Modern_Living_Room"
    static let floorName = "Modern_Living_Room_Floor_0"
    static let hiddenForDollhouse = ["Modern_Living_Room_Ceiling_0"]

    static func loadApartment() async throws -> Entity {
        let room = try await Entity(named: environmentName, in: Bundle.main)
        for name in hiddenForDollhouse {
            room.findEntity(named: name)?.isEnabled = false
        }
        let container = Entity()
        container.name = "Environment"
        container.addChild(room)

        var bounds = container.visualBounds(relativeTo: container)
        if bounds.extents.max() > 100 {
            room.scale = SIMD3<Float>(repeating: 0.01)
            bounds = container.visualBounds(relativeTo: container)
        }
        let floorY = room.findEntity(named: floorName)?.visualBounds(relativeTo: container).max.y ?? bounds.min.y
        room.position -= SIMD3<Float>(bounds.center.x, floorY, bounds.center.z)
        return container
    }

    static func addLighting(to root: Entity) {
        let sun = DirectionalLight()
        sun.light.intensity = 6000
        sun.shadow = DirectionalLightComponent.Shadow(maximumDistance: 30, depthBias: 2)
        sun.look(at: .zero, from: [4, 10, 6], relativeTo: nil)
        root.addChild(sun)

        let fill = DirectionalLight()
        fill.light.intensity = 2500
        fill.look(at: .zero, from: [-6, 8, -4], relativeTo: nil)
        root.addChild(fill)
    }
}
