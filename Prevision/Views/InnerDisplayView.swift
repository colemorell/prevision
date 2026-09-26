import SwiftUI

struct InnerDisplayView: View {
    @EnvironmentObject var scene: SceneController
    @EnvironmentObject var capture: CaptureSessionController
    @State private var outerDisplayEnabled = true

    var body: some View {
        GeometryReader { proxy in
            let division = proxy.reservedRegions(kind: .division).first { $0.isActive }
            if let division, division.frame.height > division.frame.width {
                HStack(spacing: 0) {
                    ClientView(rig: scene.client)
                        .frame(width: division.frame.minX)
                    Color.clear.frame(width: division.frame.width)
                    DesignerView()
                }
            } else {
                VStack(spacing: 0) {
                    ClientView(rig: scene.client)
                        .frame(height: division?.frame.minY ?? proxy.size.height / 2)
                    if let division {
                        Color.clear.frame(height: division.frame.height)
                    }
                    DesignerView()
                }
            }
        }
        .ignoresSafeArea()
        .sceneAccessory {
            CameraCaptureAccessory(isEnabled: $outerDisplayEnabled) {
                ClientView(rig: scene.outer)
                    .ignoresSafeArea()
            }
            .onAvailabilityChange { capture.accessoryAvailable = $0 }
        }
        .task { await capture.start() }
    }
}
