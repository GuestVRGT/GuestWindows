import SwiftUI
import GuestWindowsCore

@main
struct GuestWindowsApp: App {
    @StateObject private var vmController = VMController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vmController)
                .preferredColorScheme(.dark)
        }
        // Milestone 13 will wire scenePhase here to drive the
        // "stop emulation / flush disk / stop server" lifecycle
        // described in the project brief. Left intentionally
        // unimplemented until the controller itself does real work.
    }
}
