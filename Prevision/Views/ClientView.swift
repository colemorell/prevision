import SwiftUI
import RealityKit

struct ClientView: View {
    let rig: SceneRig

    var body: some View {
        RealityView { content in
            content.camera = .virtual
            content.add(rig.root)
        }
        .background(Brand.canvas)
    }
}
