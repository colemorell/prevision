import Foundation
import simd

struct FurnitureItem: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let url: URL
    let targetSizeMeters: SIMD3<Float>?
    let zUp: Bool
    let isImported: Bool
}
