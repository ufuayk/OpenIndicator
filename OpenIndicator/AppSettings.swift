import Foundation
import ServiceManagement
import Combine

final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    // Launch at login

    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != (SMAppService.mainApp.status == .enabled) else { return }
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("OpenIndicator: failed to update launch-at-login: \(error.localizedDescription)")

                launchAtLogin = (SMAppService.mainApp.status == .enabled)
            }
        }
    }

    // Refresh interval

    @Published var refreshInterval: Double {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: Keys.refreshInterval)
        }
    }

    // Menu bar glyph contents

    @Published var showBatteryRing: Bool {
        didSet { UserDefaults.standard.set(showBatteryRing, forKey: Keys.showBatteryRing) }
    }
    @Published var showWifiGlyph: Bool {
        didSet { UserDefaults.standard.set(showWifiGlyph, forKey: Keys.showWifiGlyph) }
    }
    @Published var showVolumeDots: Bool {
        didSet { UserDefaults.standard.set(showVolumeDots, forKey: Keys.showVolumeDots) }
    }

    // Notifications

    @Published var lowBatteryAlertsEnabled: Bool {
        didSet { UserDefaults.standard.set(lowBatteryAlertsEnabled, forKey: Keys.lowBatteryAlerts) }
    }

    private enum Keys {
        static let refreshInterval = "refreshInterval"
        static let showBatteryRing = "showBatteryRing"
        static let showWifiGlyph = "showWifiGlyph"
        static let showVolumeDots = "showVolumeDots"
        static let lowBatteryAlerts = "lowBatteryAlertsEnabled"
    }

    private init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            Keys.refreshInterval: 2.0,
            Keys.showBatteryRing: true,
            Keys.showWifiGlyph: true,
            Keys.showVolumeDots: true,
            Keys.lowBatteryAlerts: true,
        ])

        launchAtLogin = (SMAppService.mainApp.status == .enabled)
        refreshInterval = defaults.double(forKey: Keys.refreshInterval)
        showBatteryRing = defaults.bool(forKey: Keys.showBatteryRing)
        showWifiGlyph = defaults.bool(forKey: Keys.showWifiGlyph)
        showVolumeDots = defaults.bool(forKey: Keys.showVolumeDots)
        lowBatteryAlertsEnabled = defaults.bool(forKey: Keys.lowBatteryAlerts)
    }
}
