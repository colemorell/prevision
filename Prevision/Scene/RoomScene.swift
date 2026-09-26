import RealityKit
import Foundation
import simd

enum RoomScene {
    static func loadApartment() async throws -> Entity {
        let apartment = try await Entity(named: "Modern_Apartment", in: Bundle.main)
        var transform = apartment.transform
        transform.scale = [0.01, 0.01, 0.01]
        apartment.move(to: transform, relativeTo: apartment.parent, duration: 0, timingFunction: .linear)
        return apartment
    }

    static func makeAnchor() -> AnchorEntity {
        return AnchorEntity(world: .zero)
    }

    static func addLighting(to root: Entity) {
        let light = DirectionalLight()
        light.light.intensity = 2000
        light.light.color = .white
        light.orientation = simd_quatf(angle: -.pi / 3, axis: [1, 0, 0])
        root.addChild(light)
    }
}
