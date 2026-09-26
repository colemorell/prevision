import Foundation
import simd

struct Note: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let position: SIMD3<Float>
    let room: String

    init(id: UUID = UUID(), text: String, position: SIMD3<Float>, room: String) {
        self.id = id
        self.text = text
        self.position = position
        self.room = room
    }

    enum CodingKeys: String, CodingKey {
        case id, text, position, room
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        room = try container.decode(String.self, forKey: .room)

        let positionContainer = try container.nestedContainer(keyedBy: PositionCodingKeys.self, forKey: .position)
        let x = try positionContainer.decode(Float.self, forKey: .x)
        let y = try positionContainer.decode(Float.self, forKey: .y)
        let z = try positionContainer.decode(Float.self, forKey: .z)
        position = SIMD3<Float>(x, y, z)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(room, forKey: .room)

        var positionContainer = container.nestedContainer(keyedBy: PositionCodingKeys.self, forKey: .position)
        try positionContainer.encode(position.x, forKey: .x)
        try positionContainer.encode(position.y, forKey: .y)
        try positionContainer.encode(position.z, forKey: .z)
    }

    enum PositionCodingKeys: String, CodingKey {
        case x, y, z
    }
}
