import RealityKit
import SwiftUI
import simd

enum RaycastPlacement {
    static func loadModel(for item: FurnitureItem) async throws -> Entity {
        let model = try await Entity(named: item.usdz, in: Bundle.main)
        if item.zUp {
            model.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        }

        let oriented = Entity()
        oriented.addChild(model)
        let raw = oriented.visualBounds(relativeTo: oriented)
        if raw.extents.y > 0 {
            oriented.scale = SIMD3<Float>(repeating: item.targetSizeMeters.y / raw.extents.y)
        }

        let wrapper = Entity()
        wrapper.name = item.id
        wrapper.addChild(oriented)
        let fitted = wrapper.visualBounds(relativeTo: wrapper)
        oriented.position -= SIMD3<Float>(fitted.center.x, fitted.min.y, fitted.center.z)

        let size = wrapper.visualBounds(relativeTo: wrapper).extents
        wrapper.components.set(CollisionComponent(shapes: [ShapeResource.generateBox(size: size).offsetBy(translation: [0, size.y / 2, 0])]))
        wrapper.components.set(InputTargetComponent())
        return wrapper
    }

    static func floorPoint(tap: CGPoint, viewSize: CGSize, camera: Entity, fovDegrees: Float) -> SIMD3<Float>? {
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }
        let aspect = Float(viewSize.width / viewSize.height)
        let tanHalf = tan(fovDegrees * .pi / 360)
        let ndcX = Float(tap.x / viewSize.width) * 2 - 1
        let ndcY = 1 - Float(tap.y / viewSize.height) * 2
        let local = normalize(SIMD3<Float>(ndcX * tanHalf * aspect, ndcY * tanHalf, -1))

        let transform = camera.transformMatrix(relativeTo: nil)
        let origin = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        let dir4 = transform * SIMD4<Float>(local, 0)
        let direction = normalize(SIMD3<Float>(dir4.x, dir4.y, dir4.z))

        guard abs(direction.y) > 1e-4 else { return nil }
        let t = -origin.y / direction.y
        guard t > 0 else { return nil }
        return origin + direction * t
    }
}
