import SwiftUI

struct InnerDisplayView: View {
    @EnvironmentObject var scene: SceneController
    @EnvironmentObject var capture: CaptureSessionController
    @State private var outerDisplayEnabled = true
    let onClose: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let division = proxy.hingeDivision
            if let division, division.height > division.width {
                HStack(spacing: 0) {
                    ClientView(rig: scene.client, revision: scene.revision)
                        .frame(width: division.minX)
                    Color.clear.frame(width: division.width)
                    DesignerView(onClose: onClose)
                }
            } else {
                VStack(spacing: 0) {
                    ClientView(rig: scene.client, revision: scene.revision)
                        .frame(height: division?.minY ?? proxy.size.height / 2)
                    if let division {
                        Color.clear.frame(height: division.height)
                    }
                    DesignerView(onClose: onClose)
                }
            }
        }
        .ignoresSafeArea()
        .modifier(OuterDisplayModifier(scene: scene, isEnabled: $outerDisplayEnabled))
        .task { await capture.start() }
        .onDisappear { capture.stop() }
    }
}
