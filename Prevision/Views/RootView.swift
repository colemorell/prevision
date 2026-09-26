import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: DesignStore
    @EnvironmentObject var library: FurnitureLibrary
    @EnvironmentObject var scene: SceneController
    @State private var openDesignID: UUID?

    var body: some View {
        ZStack {
            if openDesignID != nil {
                InnerDisplayView(onClose: close)
                    .background(Brand.canvas)
                    .transition(.move(edge: .trailing))
                    .zIndex(1)
            } else {
                HomeView(onOpen: open)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .offset(x: -80)), removal: .opacity.combined(with: .offset(x: -80))))
            }
        }
        .animation(Brand.Motion.standard, value: openDesignID)
        .task {
            scene.onDesignChange = { store.save($0) }
            scene.preload(library: library)
        }
    }

    private func open(_ design: Design) {
        openDesignID = design.id
        Task { await scene.open(design, library: library) }
    }

    private func close() {
        scene.close()
        openDesignID = nil
    }
}
