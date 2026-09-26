import Foundation
import simd

struct Placement: Identifiable, Codable, Hashable {
    let id: UUID
    var itemID: String
    var position: SIMD3<Float>
    var yaw: Float

    init(id: UUID = UUID(), itemID: String, position: SIMD3<Float>, yaw: Float) {
        self.id = id
        self.itemID = itemID
        self.position = position
        self.yaw = yaw
    }
}

struct Design: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date
    var placements: [Placement]
    var notes: [Note]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        placements: [Placement] = [],
        notes: [Note] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.placements = placements
        self.notes = notes
    }
}
