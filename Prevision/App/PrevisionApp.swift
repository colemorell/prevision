import SwiftUI

@main
struct PrevisionApp: App {
    @StateObject private var catalog = FurnitureCatalog()
    @StateObject private var scene = SceneController()
    @StateObject private var capture = CaptureSessionController()

    var body: some Scene {
        WindowGroup {
            InnerDisplayView()
                .environmentObject(catalog)
                .environmentObject(scene)
                .environmentObject(capture)
        }
    }
}
