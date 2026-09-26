import SwiftUI

struct InnerDisplayView: View {
    @EnvironmentObject var scene: SceneController
    @EnvironmentObject var capture: CaptureSessionController
    @State private var outerDisplayEnabled = true
    @State private var hasHinge = false
    let onClose: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let division = proxy.hingeDivision
            Group {
                if let division, division.height > division.width {
                    HStack(spacing: 0) {
                        ClientView(rig: scene.client, revision: scene.revision)
                            .frame(width: division.minX)
                        Color.clear.frame(width: division.width)
                        DesignerView(onClose: onClose)
                    }
                    .ignoresSafeArea()
                } else if let division {
                    VStack(spacing: 0) {
                        ClientView(rig: scene.client, revision: scene.revision)
                            .frame(height: division.minY)
                        Color.clear.frame(height: division.height)
                        DesignerView(onClose: onClose)
                    }
                    .ignoresSafeArea()
                } else {
                    DesignerView(onClose: onClose)
                }
            }
            .onAppear { hasHinge = division != nil }
            .onChange(of: division != nil) { _, present in hasHinge = present }
        }
        .modifier(OuterDisplayModifier(scene: scene, isEnabled: $outerDisplayEnabled))
        .task(id: hasHinge) {
            if hasHinge {
                await capture.start()
            } else {
                capture.stop()
            }
        }
        .onDisappear { capture.stop() }
    }
}
