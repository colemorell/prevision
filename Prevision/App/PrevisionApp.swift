import SwiftUI

@main
struct PrevisionApp: App {
    @StateObject private var store = DesignStore()
    @StateObject private var library = FurnitureLibrary()
    @StateObject private var scene = SceneController()
    @StateObject private var capture = CaptureSessionController()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(library)
                .environmentObject(scene)
                .environmentObject(capture)
        }
    }
}
