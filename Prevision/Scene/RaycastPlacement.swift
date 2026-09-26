import RealityKit
import SwiftUI
import simd

struct Ray {
    let origin: SIMD3<Float>
    let direction: SIMD3<Float>

    var floorPoint: SIMD3<Float>? {
        guard abs(direction.y) > 1e-4 else { return nil }
        let t = -origin.y / direction.y
        return t > 0 ? origin + direction * t : nil
    }

    func distance(to bounds: BoundingBox) -> Float? {
        var tMin: Float = 0
        var tMax = Float.greatestFiniteMagnitude
        for axis in 0..<3 {
            let d = direction[axis]
            if abs(d) < 1e-6 {
                if origin[axis] < bounds.min[axis] || origin[axis] > bounds.max[axis] { return nil }
                continue
            }
            var t1 = (bounds.min[axis] - origin[axis]) / d
            var t2 = (bounds.max[axis] - origin[axis]) / d
            if t1 > t2 { swap(&t1, &t2) }
            tMin = max(tMin, t1)
            tMax = min(tMax, t2)
            if tMin > tMax { return nil }
        }
        return tMin
    }
}

enum RaycastPlacement {
    static func loadModel(for item: FurnitureItem) async throws -> Entity {
        let model = try await Entity(contentsOf: item.url)
        if item.zUp {
            model.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        }

        let oriented = Entity()
        oriented.addChild(model)
        let raw = oriented.visualBounds(relativeTo: oriented)
        if let target = item.targetSizeMeters, raw.extents.y > 0 {
            oriented.scale = SIMD3<Float>(repeating: target.y / raw.extents.y)
        } else if raw.extents.max() > 20 {
            oriented.scale = SIMD3<Float>(repeating: 0.01)
        }

        let wrapper = Entity()
        wrapper.name = item.id
        wrapper.addChild(oriented)
        let fitted = wrapper.visualBounds(relativeTo: wrapper)
        oriented.position -= SIMD3<Float>(fitted.center.x, fitted.min.y, fitted.center.z)
        return wrapper
    }

    static func ray(tap: CGPoint, viewSize: CGSize, camera: Entity, horizontalFovDegrees: Float) -> Ray? {
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }
        let aspect = Float(viewSize.width / viewSize.height)
        let tanHalf = tan(horizontalFovDegrees * .pi / 360)
        let ndcX = Float(tap.x / viewSize.width) * 2 - 1
        let ndcY = 1 - Float(tap.y / viewSize.height) * 2
        let local = normalize(SIMD3<Float>(ndcX * tanHalf, ndcY * tanHalf / aspect, -1))

        let transform = camera.transformMatrix(relativeTo: nil)
        let origin = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        let world = transform * SIMD4<Float>(local, 0)
        return Ray(origin: origin, direction: normalize(SIMD3<Float>(world.x, world.y, world.z)))
    }
}
