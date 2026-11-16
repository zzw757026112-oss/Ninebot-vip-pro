import SwiftUI

/// Ninebot Pro — clean-room rebuild, version 1.1.0.
/// Deployment target is iOS 16.0. All state uses the pre-16.4
/// ObservableObject pattern: @StateObject at the root and
/// @ObservedObject / @EnvironmentObject below it.
@main
struct NinebotProApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(appState)
                .onAppear {
                    // First-run work belongs here, not in a two-argument
                    // onChange handler (that overload is not available
                    // on the deployment target).
                    appState.checkForUpdateIfDue()
                }
        }
    }
}
