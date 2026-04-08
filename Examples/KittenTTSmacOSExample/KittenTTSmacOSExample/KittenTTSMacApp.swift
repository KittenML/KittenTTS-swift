import SwiftUI

@main
struct KittenTTSMacApp: App {
    var body: some Scene {
        WindowGroup("KittenTTS") {
            ContentView()
                .frame(minWidth: 500, minHeight: 520)
        }
        .windowResizability(.contentMinSize)
    }
}
