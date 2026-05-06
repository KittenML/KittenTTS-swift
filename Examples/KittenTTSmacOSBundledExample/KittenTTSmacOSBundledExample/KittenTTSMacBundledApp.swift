import SwiftUI

@main
struct KittenTTSMacBundledApp: App {
    var body: some Scene {
        WindowGroup("KittenTTS Bundled Assets") {
            ContentView()
                .frame(minWidth: 640, minHeight: 520)
        }
        .windowResizability(.contentMinSize)
    }
}
