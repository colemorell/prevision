import SwiftUI

@main
struct PrevisionApp: App {
    @StateObject private var catalog = FurnitureCatalog()
    @StateObject private var scene = SceneController()
    @StateObject private var externalDisplay = ExternalDisplayManager()

    var body: some Scene {
        WindowGroup {
            InnerDisplayView()
                .environmentObject(catalog)
                .environmentObject(scene)
                .environmentObject(externalDisplay)
                .onAppear {
                    externalDisplay.startObserving()
                }
        }
    }
}
