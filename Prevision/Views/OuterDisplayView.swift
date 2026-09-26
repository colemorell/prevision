import SwiftUI

nonisolated struct OuterDisplayView: View {
    @ObservedObject var scene: SceneController

    var body: some View {
        RotatedClientView(scene: scene)
    }
}

private struct RotatedClientView: View {
    @ObservedObject var scene: SceneController
    @AppStorage("clientScreenRotation") private var rotation = 90.0

    var body: some View {
        GeometryReader { proxy in
            let size = rotation != 0 ? CGSize(width: proxy.size.height, height: proxy.size.width) : proxy.size
            ClientView(rig: scene.outer, revision: scene.revision) { location, viewSize in
                scene.handleClientTap(at: location, viewSize: viewSize)
            }
            .frame(width: size.width, height: size.height)
            .rotationEffect(.degrees(rotation))
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .background(Brand.canvas)
        .ignoresSafeArea()
    }
}

@available(iOS 27.1, *)
nonisolated enum OuterAccessory {
    static func make(scene: SceneController, isEnabled: Binding<Bool>) -> some SceneAccessoryContent {
        CameraCaptureAccessory(isEnabled: isEnabled) {
            OuterDisplayView(scene: scene)
        }
    }
}

struct OuterDisplayModifier: ViewModifier {
    let scene: SceneController
    @Binding var isEnabled: Bool

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.sceneAccessory {
                OuterAccessory.make(scene: scene, isEnabled: $isEnabled)
            }
        } else {
            content
        }
    }
}
