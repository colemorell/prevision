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
            let isVertical = division.map { $0.height > $0.width } ?? false
            let layout = isVertical ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
            layout {
                if let division {
                    ClientView(rig: scene.client, revision: scene.revision)
                        .frame(width: isVertical ? division.minX : nil, height: isVertical ? nil : division.minY)
                    Color.clear
                        .frame(width: isVertical ? division.width : nil, height: isVertical ? nil : division.height)
                }
                DesignerView(onClose: onClose)
            }
            .ignoresSafeArea(edges: division == nil ? [] : .all)
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
