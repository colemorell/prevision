import RealityKit
import Foundation
import simd

final class SceneRig {
    let root = Entity()
    let camera = PerspectiveCamera()
    var light: Entity?
    var directionalLights: [(light: DirectionalLight, base: Float)] = []
    private weak var owner: Entity?
    var subscription: EventSubscription?

    private var heartbeat: (entity: Entity, animation: AnimationResource)?
    private var heartbeatController: AnimationPlaybackController?

    init() {
        camera.camera.fieldOfViewInDegrees = SceneController.horizontalFovDegrees
        camera.camera.fieldOfViewOrientation = .horizontal
        root.addChild(camera)
        if !ProcessInfo.processInfo.arguments.contains("-UITests"), let heartbeat = Self.makeHeartbeat() {
            root.addChild(heartbeat.entity)
            self.heartbeat = heartbeat
        }
    }

    func attach(to holder: Entity) {
        owner = holder
        if root.parent !== holder { holder.addChild(root) }
        startHeartbeat()
    }

    func keepAttached(to holder: Entity) {
        guard owner === holder else { return }
        if root.parent !== holder {
            holder.addChild(root)
            startHeartbeat()
        } else if heartbeat != nil, heartbeatController?.isValid != true || heartbeatController?.isPlaying != true {
            startHeartbeat()
        }
    }

    private func startHeartbeat() {
        guard let heartbeat else { return }
        heartbeat.entity.stopAllAnimations()
        heartbeatController = heartbeat.entity.playAnimation(heartbeat.animation)
    }

    private static func makeHeartbeat() -> (entity: Entity, animation: AnimationResource)? {
        let pulse = ModelEntity(mesh: .generateBox(size: 0.001), materials: [UnlitMaterial(color: .clear)])
        pulse.components.set(OpacityComponent(opacity: 0))
        let spin = FromToByAnimation<Transform>(
            from: Transform(rotation: simd_quatf(angle: 0, axis: [0, 1, 0])),
            to: Transform(rotation: simd_quatf(angle: .pi, axis: [0, 1, 0])),
            duration: 1,
            bindTarget: .transform,
            repeatMode: .repeat
        )
        guard let resource = try? AnimationResource.generate(with: spin) else { return nil }
        return (pulse, resource)
    }
}
