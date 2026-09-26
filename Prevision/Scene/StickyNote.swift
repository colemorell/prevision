import RealityKit
import UIKit

enum StickyNote {
    static func make(text: String) -> Entity {
        let root = Entity()
        root.name = "StickyNote"

        let stemHeight: Float = 0.9
        let stemRadius: Float = 0.012
        let cardSize: Float = 0.45
        let cardThickness: Float = 0.012
        let margin: Float = 0.045

        let stemMesh = MeshResource.generateCylinder(height: stemHeight, radius: stemRadius)
        var stemMaterial = UnlitMaterial()
        stemMaterial.color = .init(tint: UIColor(white: 0.18, alpha: 1))
        let stem = ModelEntity(mesh: stemMesh, materials: [stemMaterial])
        stem.position = SIMD3<Float>(0, stemHeight / 2, 0)
        root.addChild(stem)

        let billboard = Entity()
        billboard.position = SIMD3<Float>(0, stemHeight, 0)
        billboard.components.set(BillboardComponent())
        root.addChild(billboard)

        let cardMesh = MeshResource.generateBox(
            width: cardSize,
            height: cardSize,
            depth: cardThickness,
            cornerRadius: 0.02
        )
        var cardMaterial = UnlitMaterial()
        cardMaterial.color = .init(tint: UIColor.systemYellow)
        let card = ModelEntity(mesh: cardMesh, materials: [cardMaterial])
        billboard.addChild(card)

        let containerSide = cardSize - margin * 2
        let containerFrame = CGRect(
            x: 0,
            y: 0,
            width: Double(containerSide),
            height: Double(containerSide)
        )
        let truncatedText = String(text.prefix(140))
        let font = MeshResource.Font.systemFont(ofSize: 0.07)
        let textMesh = MeshResource.generateText(
            truncatedText,
            extrusionDepth: 0.0015,
            font: font,
            containerFrame: containerFrame,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        var textMaterial = UnlitMaterial()
        textMaterial.color = .init(tint: UIColor(white: 0.12, alpha: 1))
        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])

        let textBounds = textMesh.bounds
        let textCenter = SIMD3<Float>(
            (textBounds.min.x + textBounds.max.x) / 2,
            (textBounds.min.y + textBounds.max.y) / 2,
            (textBounds.min.z + textBounds.max.z) / 2
        )
        textEntity.position = SIMD3<Float>(
            -textCenter.x,
            -textCenter.y,
            cardThickness / 2 + 0.002 - textCenter.z
        )
        billboard.addChild(textEntity)

        return root
    }
}
