import SwiftUI
import RealityKit

struct ClientView: View {
    let rig: SceneRig
    let revision: Int
    var onTap: ((CGPoint, CGSize) -> Void)?

    var body: some View {
        GeometryReader { geo in
            RealityView { content in
                content.camera = .virtual
                content.add(rig.root)
            } update: { content in
                _ = revision
                if rig.root.scene == nil { content.add(rig.root) }
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
