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

extension GeometryProxy {
    var hingeDivision: CGRect? {
        if #available(iOS 27.1, *) {
            return reservedRegions(kind: .division).first { $0.isActive }?.frame
        }
        return nil
    }
}
