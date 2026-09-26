import SwiftUI

nonisolated struct OuterDisplayView: View {
    @ObservedObject var scene: SceneController

    var body: some View {
        ClientView(rig: scene.outer, revision: scene.revision) { location, size in
            scene.handleClientTap(at: location, viewSize: size)
        }
        .ignoresSafeArea()
    }
}

nonisolated enum OuterAccessory {
    static func make(scene: SceneController, isEnabled: Binding<Bool>) -> some SceneAccessoryContent {
        CameraCaptureAccessory(isEnabled: isEnabled) {
            OuterDisplayView(scene: scene)
        }
    }
}
