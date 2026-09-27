import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 12) {
            SettingsCard {
                SettingsToggleRow(
                    title: "Launch at login",
                    subtitle: "Starts OpenIndicator automatically when you sign in.",
                    isOn: $settings.launchAtLogin
                )
            }

            SettingsCard(title: "Menu bar glyph") {
                SettingsToggleRow(title: "Battery ring", isOn: $settings.showBatteryRing)
                Divider()
                SettingsToggleRow(title: "Wi-Fi signal", isOn: $settings.showWifiGlyph)
                Divider()
                SettingsToggleRow(title: "Volume dots", isOn: $settings.showVolumeDots)
                Text("Turning all three off leaves an empty glyph — at least one is recommended.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }

            SettingsCard(title: "Updates") {
                HStack {
                    Text("Refresh every")
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $settings.refreshInterval) {
                        Text("1 second").tag(1.0)
                        Text("2 seconds").tag(2.0)
                        Text("5 seconds").tag(5.0)
                        Text("10 seconds").tag(10.0)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 130)
                }
            }

            SettingsCard(title: "Notifications") {
                SettingsToggleRow(
                    title: "Alert when battery is low",
                    isOn: $settings.lowBatteryAlertsEnabled
                )
            }

            Divider()
                .padding(.top, 2)

            HStack {
                Text("OpenIndicator")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(appVersionString)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 2)
        }
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }
}

private struct SettingsCard<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 8) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .panelSection()
    }
}

private struct SettingsToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Toggle(isOn: $isOn) {
                Text(title)
                    .font(.system(size: 12))
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SettingsView()
        .frame(width: 312)
        .padding()
}
