import SwiftUI
import RealityKit

struct ClientView: View {
    let rig: SceneRig
    let revision: Int
    var onTap: ((CGPoint, CGSize) -> Void)?
    @State private var holder = Entity()

    var body: some View {
        GeometryReader { geo in
            RealityView { content in
                content.camera = .virtual
                let rig = self.rig
                let holder = self.holder
                content.add(holder)
                rig.attach(to: holder)
                rig.subscription = content.subscribe(to: SceneEvents.Update.self) { _ in
                    MainActor.assumeIsolated { rig.keepAttached(to: holder) }
                }
            } update: { _ in
                _ = revision
                rig.keepAttached(to: holder)
            }
            .background(Brand.canvas)
            .gesture(
                SpatialTapGesture().onEnded { value in
                    onTap?(value.location, geo.size)
                },
                isEnabled: onTap != nil
            )
        }
    }
}
