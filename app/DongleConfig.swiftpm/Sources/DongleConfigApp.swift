import SwiftUI

@main
struct DongleConfigApp: App {
    @StateObject private var detector = USBDetector()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(detector)
        }
        .windowResizability(.contentSize)
    }
}
