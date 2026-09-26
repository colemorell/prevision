import Foundation
import simd

struct FurnitureItem: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let usdz: String
    let widthInches: Double
    let depthInches: Double
    let heightInches: Double
    let sourceUnit: String
    let zUp: Bool

    var targetSizeMeters: SIMD3<Float> {
        let inchesToMeters: Float = 0.0254
        return SIMD3<Float>(
            Float(widthInches) * inchesToMeters,
            Float(heightInches) * inchesToMeters,
            Float(depthInches) * inchesToMeters
        )
    }
}
