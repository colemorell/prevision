import SwiftUI

struct InnerDisplayView: View {
    @EnvironmentObject var scene: SceneController
    @EnvironmentObject var capture: CaptureSessionController
    @State private var outerDisplayEnabled = true
    let onClose: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let division = proxy.reservedRegions(kind: .division).first { $0.isActive }
            if let division, division.frame.height > division.frame.width {
                HStack(spacing: 0) {
                    ClientView(rig: scene.client, revision: scene.revision)
                        .frame(width: division.frame.minX)
                    Color.clear.frame(width: division.frame.width)
                    DesignerView(onClose: onClose)
                }
            } else {
                VStack(spacing: 0) {
                    ClientView(rig: scene.client, revision: scene.revision)
                        .frame(height: division?.frame.minY ?? proxy.size.height / 2)
                    if let division {
                        Color.clear.frame(height: division.frame.height)
                    }
                    DesignerView(onClose: onClose)
                }
            }
        }
        .ignoresSafeArea()
        .sceneAccessory {
            OuterAccessory.make(scene: scene, isEnabled: $outerDisplayEnabled)
        }
        .task { await capture.start() }
        .onDisappear { capture.stop() }
    }
}
