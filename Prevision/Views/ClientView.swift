import SwiftUI
import RealityKit

struct ClientView: View {
    @EnvironmentObject var scene: SceneController

    var body: some View {
        RealityView { content in
            content.add(scene.rootAnchor)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ClientView()
        .environmentObject(SceneController())
}
