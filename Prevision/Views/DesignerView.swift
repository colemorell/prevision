import SwiftUI
import RealityKit

struct DesignerView: View {
    @EnvironmentObject var catalog: FurnitureCatalog
    @EnvironmentObject var scene: SceneController
    @EnvironmentObject var externalDisplay: ExternalDisplayManager

    @State private var showNotes = false
    @State private var lastMagnifyScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            RealityView { content in
                content.add(scene.rootAnchor)
            }
            .gesture(MagnifyGesture()
                .onChanged { value in
                    scene.handleZoom(Float(value.magnification - lastMagnifyScale))
                    lastMagnifyScale = value.magnification
                }
                .onEnded { _ in
                    lastMagnifyScale = 1.0
                })
            .gesture(DragGesture()
                .onChanged { value in
                    scene.handleOrbit(deltaX: Float(value.translation.width), deltaY: Float(value.translation.height))
                })
            .ignoresSafeArea()

            VStack {
                HStack {
                    if externalDisplay.externalScreenConnected {
                        Image(systemName: "display.2")
                            .font(.headline)
                            .padding(8)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(6)
                    }
                    Spacer()
                    Button(action: { showNotes.toggle() }) {
                        Image(systemName: "note.text")
                            .font(.headline)
                    }
                    .padding()
                }
                .padding()

                Spacer()

                FurnitureListView()
                    .padding()
            }

            if showNotes {
                NotesListView()
                    .transition(.move(edge: .trailing))
            }
        }
        .task {
            await scene.setup()
        }
    }
}

#Preview {
    DesignerView()
        .environmentObject(FurnitureCatalog())
        .environmentObject(SceneController())
        .environmentObject(ExternalDisplayManager())
}
