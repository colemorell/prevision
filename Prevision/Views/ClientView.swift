import SwiftUI
import RealityKit

struct ClientView: View {
    @EnvironmentObject var scene: SceneController

    var body: some View {
        RealityView { content in
            content.camera = .virtual
            content.add(scene.client.root)
        }
        .background(Brand.canvas)
    }
}
