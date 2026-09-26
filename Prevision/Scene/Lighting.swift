import RealityKit
import Foundation
import ImageIO

enum Lighting {
    private static let resourceName = "interior_ibl"
    private static let resourceExtension = "png"

    private static var cachedResource: EnvironmentResource?

    @discardableResult
    static func apply(to root: Entity) async -> Entity? {
        guard let resource = await loadResource() else { return nil }

        let light = Entity()
        light.name = "IBLEnvironment"
        light.components.set(ImageBasedLightComponent(source: .single(resource), intensityExponent: 1))
        root.addChild(light)

        root.components.set(ImageBasedLightReceiverComponent(imageBasedLight: light))
        receive(root, light: light)
        return light
    }

    static func receive(_ entity: Entity, light: Entity) {
        if entity.components.has(ModelComponent.self) {
            entity.components.set(ImageBasedLightReceiverComponent(imageBasedLight: light))
        }
        for child in entity.children {
            receive(child, light: light)
        }
    }

    private static func loadResource() async -> EnvironmentResource? {
        if let cachedResource {
            return cachedResource
        }
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }
        guard let resource = try? await EnvironmentResource(
            equirectangular: cgImage,
            options: EnvironmentResource.CreateOptions()
        ) else {
            return nil
        }
        cachedResource = resource
        return resource
    }
}
