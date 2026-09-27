import SwiftUI
import AppKit

struct RingPanelView: View {
    @EnvironmentObject private var monitor: SystemMonitor
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var appearance = AppearancePreferences.shared

    enum InitialScreen {
        case status
        case settings
    }

    @State private var screen: Screen

    private enum Screen {
        case status
        case settings
    }

    private let githubHandle = "ufuayk"

    init(initialScreen: InitialScreen = .status) {
        _screen = State(initialValue: initialScreen == .settings ? .settings : .status)
    }

    var body: some View {
        Group {
            switch screen {
            case .status:
                statusContent
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            case .settings:
                settingsContent
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .frame(width: 312)

        .compositingGroup()
    }

    private var statusContent: some View {
        VStack(spacing: 0) {
            header
            Divider().padding(.horizontal, 18)
            sections
            PanelFooter(
                githubHandle: githubHandle,
                onSettings: {
                    withAnimation(.easeInOut(duration: 0.22)) { screen = .settings }
                }
            )
        }
    }

    // Settings 

    private var settingsContent: some View {
        VStack(spacing: 0) {
            settingsHeader
            Divider().padding(.horizontal, 18)
            SettingsView()
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
        }
    }

    private var settingsHeader: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { screen = .status }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .contentShape(Circle())
            }
            .buttonStyle(TapFeedbackButtonStyle())
            .liquidGlassCapsule()
            .help("Back")

            Text("Settings")
                .font(.system(size: 15, weight: .semibold, design: .rounded))

            Spacer(minLength: 0)
        }
        .padding(18)
    }

    // Header

    private var header: some View {
        HStack(spacing: 14) {
            RingIcon(
                volume: monitor.volume,
                isMuted: monitor.isMuted,
                batteryLevel: monitor.batteryPercentage,
                isCharging: monitor.isCharging,
                signalBars: monitor.wifiSignalBars,
                wifiConnected: monitor.wifiConnected,
                size: 58,
                showBattery: settings.showBatteryRing,
                showWifi: settings.showWifiGlyph,
                showVolume: settings.showVolumeDots
            )

            VStack(alignment: .leading, spacing: 3) {
                Text("OpenIndicator")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(headlineSummary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                    .animation(.easeInOut(duration: 0.2), value: headlineSummary)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
    }

    private var headlineSummary: String {
        var parts: [String] = []
        if monitor.wifiConnected {
            parts.append(monitor.wifiNetworkName)
        } else {
            parts.append("No Wi-Fi")
        }
        if let minutes = monitor.batteryMinutesRemaining, !monitor.isPluggedIn {
            parts.append("\(formatted(minutes: minutes)) left")
        } else if monitor.isCharging {
            parts.append("Charging")
        }
        return parts.joined(separator: " · ")
    }

    private var sections: some View {
        VStack(spacing: 10) {
            // ---- Battery ----
            MetricSection(
                icon: batteryIcon,
                tint: batteryTint,
                title: "Battery",
                headline: "\(monitor.batteryPercentage)%"
            ) {
                MeterBar(
                    fraction: Double(monitor.batteryPercentage) / 100.0,
                    tint: batteryTint,
                    flat: appearance.reduceTransparency
                )
                DetailLine(label: "Power", value: powerSourceLabel)
                if let minutes = monitor.batteryMinutesRemaining {
                    DetailLine(
                        label: monitor.isCharging ? "Until full" : "Remaining",
                        value: formatted(minutes: minutes)
                    )
                }
                if monitor.isLowPowerModeEnabled {
                    DetailLine(label: "Low Power Mode", value: "On")
                }
            }

            // ---- Wi-Fi ----
            MetricSection(
                icon: monitor.wifiConnected ? "wifi" : "wifi.slash",
                tint: .primary,
                title: "Wi-Fi",
                headline: monitor.wifiNetworkName
            ) {
                if monitor.wifiConnected {
                    if monitor.wifiRSSI != 0 {
                        DetailLine(
                            label: "Signal",
                            value: "\(monitor.wifiRSSI) dBm\(signalQualityLabel)"
                        )
                    }
                    if monitor.wifiNoise != 0 {
                        DetailLine(label: "Noise", value: "\(monitor.wifiNoise) dBm")
                    }
                    if monitor.wifiTransmitRate > 0 {
                        DetailLine(
                            label: "Link rate",
                            value: "\(Int(monitor.wifiTransmitRate)) Mbps"
                        )
                    }
                    if monitor.wifiChannel > 0 {
                        DetailLine(
                            label: "Channel",
                            value: monitor.wifiBand.isEmpty
                                ? "\(monitor.wifiChannel)"
                                : "\(monitor.wifiChannel) · \(monitor.wifiBand)"
                        )
                    }
                    if !monitor.wifiSecurityType.isEmpty {
                        DetailLine(label: "Security", value: monitor.wifiSecurityType)
                    }
                    if !monitor.wifiLocalIPAddress.isEmpty {
                        DetailLine(label: "IP Address", value: monitor.wifiLocalIPAddress, copyable: true)
                    }
                }
            }

            // ---- Volume ----
            MetricSection(
                icon: monitor.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                tint: .primary,
                title: "Volume",
                headline: monitor.isMuted ? "Muted" : "\(Int(monitor.volume * 100))%"
            ) {
                HStack(spacing: 8) {
                    MeterBar(
                        fraction: monitor.isMuted ? 0 : monitor.volume,
                        tint: .primary,
                        flat: appearance.reduceTransparency
                    )
                    Button {
                        monitor.toggleMute()
                    } label: {
                        Text(monitor.isMuted ? "Unmute" : "Mute")
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 7)
                            .frame(height: 18)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(TapFeedbackButtonStyle())
                    .liquidGlassCapsule()
                }
                if !monitor.outputDeviceName.isEmpty {
                    DetailLine(label: "Output", value: monitor.outputDeviceName)
                }
            }

            // ---- CPU ----
            if let cpuUsage = monitor.cpuUsagePercentage {
                MetricSection(
                    icon: "chart.bar.fill",
                    tint: .primary,
                    title: "CPU",
                    headline: "\(cpuUsage)%"
                ) {
                    MeterBar(
                        fraction: Double(cpuUsage) / 100.0,
                        tint: .primary,
                        flat: appearance.reduceTransparency
                    )
                }
            }

            // ---- Disk ----
            if let available = monitor.diskAvailableBytes, let total = monitor.diskTotalBytes, total > 0 {
                MetricSection(
                    icon: "internaldrive",
                    tint: .primary,
                    title: "Disk",
                    headline: byteCountFormatted(available) + " free"
                ) {
                    MeterBar(
                        fraction: 1.0 - (Double(available) / Double(total)),
                        tint: .primary,
                        flat: appearance.reduceTransparency
                    )
                    DetailLine(label: "Total", value: byteCountFormatted(total))
                }
            }

            if monitor.wifiDetailsRestricted {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("Allow Location access in System Settings › Privacy & Security to read the network name and exact signal strength.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var signalQualityLabel: String {
        switch monitor.wifiSignalBars {
        case 3: return " · excellent"
        case 2: return " · good"
        case 1: return " · weak"
        default: return ""
        }
    }

    private var powerSourceLabel: String {
        if monitor.isCharging { return "Charging" }
        if monitor.isPluggedIn { return "Adapter, not charging" }
        return "Battery"
    }

    private func formatted(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let mins = minutes % 60
        return mins == 0 ? "\(hours) hr" : "\(hours) hr \(mins) min"
    }

    private func byteCountFormatted(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useTB]
        return formatter.string(fromByteCount: bytes)
    }

    private var batteryIcon: String {
        if monitor.isCharging { return "battery.100.bolt" }
        switch monitor.batteryPercentage {
        case 0..<20: return "battery.0"
        case 20..<50: return "battery.25"
        case 50..<80: return "battery.50"
        default: return "battery.100"
        }
    }

    private var batteryTint: Color {
        .primary
    }
}

private struct PanelFooter: View {
    let githubHandle: String
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button {
                if let url = URL(string: "https://github.com/\(githubHandle)") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 10, weight: .medium))
                    Text("GitHub")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .contentShape(Capsule())
            }
            .buttonStyle(TapFeedbackButtonStyle())
            .liquidGlassCapsule()
            .help("github.com/\(githubHandle)")

            Spacer(minLength: 4)

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(TapFeedbackButtonStyle())
            .liquidGlassCapsule()
            .help("Settings")

            Spacer(minLength: 4)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "power")
                        .font(.system(size: 10, weight: .medium))
                    Text("Quit")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .contentShape(Capsule())
            }
            .buttonStyle(TapFeedbackButtonStyle())
            .liquidGlassCapsule()
            .help("Quit OpenIndicator")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .padding(.top, 2)
    }
}

private struct TapFeedbackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct MetricSection<Content: View>: View {
    let icon: String
    let tint: Color
    let title: String
    let headline: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(tint)
                    .frame(width: 17)

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                Spacer(minLength: 6)

                Text(headline)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .contentTransition(.opacity)
            }

            content
        }
        .padding(12)
        .panelSection()
        .animation(.easeInOut(duration: 0.2), value: headline)
    }
}

private struct MeterBar: View {
    let fraction: Double
    let tint: Color
    let flat: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                Capsule()
                    .fill(tint.opacity(flat ? 1.0 : 0.85))
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
                    .animation(.easeOut(duration: 0.25), value: fraction)
            }
        }
        .frame(height: 5)
    }
}

private struct DetailLine: View {
    let label: String
    let value: String
    var copyable: Bool = false

    @State private var didCopy = false

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)

            if copyable {
                Button {
                    copyToPasteboard()
                } label: {
                    Text(didCopy ? "Copied" : value)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(didCopy ? 0.55 : 0.8))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Click to copy")
            } else {
                Text(value)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private func copyToPasteboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)

        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            didCopy = false
        }
    }
}
