import SwiftUI

struct RingMenuBarLabel: View {
    @EnvironmentObject private var monitor: SystemMonitor
    @EnvironmentObject private var settings: AppSettings

    var size: CGFloat = 20

    var body: some View {
        RingIcon(
            volume: monitor.volume,
            isMuted: monitor.isMuted,
            batteryLevel: monitor.batteryPercentage,
            isCharging: monitor.isCharging,
            signalBars: monitor.wifiSignalBars,
            wifiConnected: monitor.wifiConnected,
            size: size,
            showBattery: settings.showBatteryRing,
            showWifi: settings.showWifiGlyph,
            showVolume: settings.showVolumeDots
        )
    }
}
