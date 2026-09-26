import RealityKit
import SwiftUI
import simd

enum RaycastPlacement {
    static func loadModel(for item: FurnitureItem) async throws -> Entity {
        let entity = try await Entity(named: item.usdz, in: Bundle.main)

        if item.zUp {
            let rotation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
            entity.orientation = rotation
        }

        let bounds = entity.visualBounds(relativeTo: entity)
        let extents = bounds.max - bounds.min

        var scaleFactors = SIMD3<Float>(1, 1, 1)
        if extents.x > 0 {
            scaleFactors.x = item.targetSizeMeters.x / extents.x
        }
        if extents.y > 0 {
            scaleFactors.y = item.targetSizeMeters.y / extents.y
        }
        if extents.z > 0 {
            scaleFactors.z = item.targetSizeMeters.z / extents.z
        }

        var transform = entity.transform
        transform.scale = scaleFactors
        entity.move(to: transform, relativeTo: entity, duration: 0, timingFunction: .linear)

        return entity
    }

    static func worldPoint(from screenPoint: CGPoint, in arView: RealityViewCameraContent?) -> SIMD3<Float>? {
        return nil
    }
}
