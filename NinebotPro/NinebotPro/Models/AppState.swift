import Foundation
import SwiftUI

/// Shared app state, held once at the app root as a @StateObject.
/// Persisted settings use UserDefaults; nothing here requires a
/// newer OS than the 16.0 deployment target.
final class AppState: ObservableObject {
    // MARK: - Connection

    /// Dashboard address, e.g. 192.168.43.1. On iOS the phone joins
    /// the dashboard Wi-Fi manually in Settings; the app does not
    /// scan for it.
    @Published var dashboardHost: String {
        didSet { UserDefaults.standard.set(dashboardHost, forKey: "dashboardHost") }
    }
    @Published var dashboardPort: Int {
        didSet { UserDefaults.standard.set(dashboardPort, forKey: "dashboardPort") }
    }

    // MARK: - Picture settings

    @Published var preset: DashboardPreset {
        didSet { UserDefaults.standard.set(preset.rawValue, forKey: "preset") }
    }
    @Published var cropMode: CropMode {
        didSet { UserDefaults.standard.set(cropMode.rawValue, forKey: "cropMode") }
    }
    @Published var bitrateKbps: Int {
        didSet { UserDefaults.standard.set(bitrateKbps, forKey: "bitrateKbps") }
    }
    @Published var fps: Int {
        didSet { UserDefaults.standard.set(fps, forKey: "fps") }
    }

    /// Pause capture when the app goes to the background, keeping the
    /// last frame on the dashboard (original iOS behaviour).
    @Published var pauseInBackground: Bool {
        didSet { UserDefaults.standard.set(pauseInBackground, forKey: "pauseInBackground") }
    }

    // MARK: - CarPlay receiver

    @Published var carPlayHost: String {
        didSet { UserDefaults.standard.set(carPlayHost, forKey: "carPlayHost") }
    }
    @Published var carPlayPort: Int {
        didSet { UserDefaults.standard.set(carPlayPort, forKey: "carPlayPort") }
    }

    // MARK: - Owned objects

    let log = AppLogStore()
    let session: MirrorSession
    let updateChecker: UpdateChecker

    init() {
        let defaults = UserDefaults.standard
        dashboardHost = defaults.string(forKey: "dashboardHost") ?? "192.168.43.1"
        dashboardPort = defaults.integer(forKey: "dashboardPort") == 0
            ? 5012 : defaults.integer(forKey: "dashboardPort")
        preset = DashboardPreset(rawValue: defaults.string(forKey: "preset") ?? "") ?? .fiveInch
        cropMode = CropMode(rawValue: defaults.string(forKey: "cropMode") ?? "") ?? .fit
        bitrateKbps = defaults.integer(forKey: "bitrateKbps") == 0
            ? 2000 : defaults.integer(forKey: "bitrateKbps")
        fps = defaults.integer(forKey: "fps") == 0
            ? 20 : defaults.integer(forKey: "fps")
        pauseInBackground = defaults.object(forKey: "pauseInBackground") as? Bool ?? true
        carPlayHost = defaults.string(forKey: "carPlayHost") ?? ""
        carPlayPort = defaults.integer(forKey: "carPlayPort") == 0
            ? 8080 : defaults.integer(forKey: "carPlayPort")

        session = MirrorSession(log: log)
        updateChecker = UpdateChecker(log: log)
    }

    /// Update check, at most once every 24 hours, and never while a
    /// cast is running. Called from onAppear at the app root.
    func checkForUpdateIfDue() {
        let last = UserDefaults.standard.double(forKey: "lastUpdateCheck")
        guard Date().timeIntervalSince1970 - last > 24 * 3600 else { return }
        guard !session.isCasting else { return }
        updateChecker.check { _ in
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastUpdateCheck")
        }
    }
}
