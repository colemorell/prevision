import RealityKit
import Foundation
import simd

enum RoomScene {
    static func loadApartment() async throws -> Entity {
        let apartment = try await Entity(named: "Modern_Apartment", in: Bundle.main)
        let container = Entity()
        container.name = "Apartment"
        container.addChild(apartment)

        var bounds = container.visualBounds(relativeTo: container)
        if bounds.extents.max() > 100 {
            apartment.scale = SIMD3<Float>(repeating: 0.01)
            bounds = container.visualBounds(relativeTo: container)
        }
        apartment.position -= SIMD3<Float>(bounds.center.x, bounds.min.y, bounds.center.z)
        return container
    }

    static func makeFloor(size: SIMD2<Float>) -> Entity {
        let floor = Entity()
        floor.name = "FloorCollider"
        floor.components.set(CollisionComponent(shapes: [.generateBox(width: size.x, height: 0.02, depth: size.y)]))
        floor.components.set(InputTargetComponent())
        floor.position.y = -0.01
        return floor
    }

    static func addLighting(to root: Entity) {
        let sun = DirectionalLight()
        sun.light.intensity = 12000
        sun.shadow = DirectionalLightComponent.Shadow(maximumDistance: 30, depthBias: 2)
        sun.look(at: .zero, from: [4, 10, 6], relativeTo: nil)
        root.addChild(sun)

        let fill = DirectionalLight()
        fill.light.intensity = 5000
        fill.look(at: .zero, from: [-6, 8, -4], relativeTo: nil)
        root.addChild(fill)
    }
}
