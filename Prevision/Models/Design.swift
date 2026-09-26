import Foundation
import simd

struct Placement: Identifiable, Codable, Hashable {
    let id: UUID
    var itemID: String
    var position: SIMD3<Float>
    var yaw: Float
    var scale: Float

    init(id: UUID = UUID(), itemID: String, position: SIMD3<Float>, yaw: Float, scale: Float = 1) {
        self.id = id
        self.itemID = itemID
        self.position = position
        self.yaw = yaw
        self.scale = scale
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        itemID = try container.decode(String.self, forKey: .itemID)
        position = try container.decode(SIMD3<Float>.self, forKey: .position)
        yaw = try container.decode(Float.self, forKey: .yaw)
        scale = try container.decodeIfPresent(Float.self, forKey: .scale) ?? 1
    }
}

struct Design: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date
    var placements: [Placement]
    var notes: [Note]
    var lightLevel: Float?

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
