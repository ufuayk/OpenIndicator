import Foundation
import IOKit.ps
import CoreWLAN
import CoreAudio
import CoreLocation
import Network
import Combine
import UserNotifications

final class SystemMonitor: NSObject, ObservableObject {

    @Published var batteryPercentage: Int = 100
    @Published var isCharging: Bool = false
    @Published var isPluggedIn: Bool = false

    @Published var wifiConnected: Bool = false
    @Published var wifiNetworkName: String = "—"
    @Published var wifiSignalBars: Int = 0
    @Published var wifiRSSI: Int = 0
    @Published var wifiTransmitRate: Double = 0
    @Published var wifiDetailsRestricted: Bool = false

    @Published var batteryMinutesRemaining: Int?

    @Published var isLowPowerModeEnabled: Bool = false

    private var didSendLowBatteryAlert = false
    private let lowBatteryThreshold = 15

    @Published var wifiChannel: Int = 0
    @Published var wifiBand: String = ""
    @Published var wifiNoise: Int = 0
    @Published var wifiLocalIPAddress: String = ""
    @Published var wifiSecurityType: String = ""

    @Published var volume: Double = 0.0   // 0.0 ... 1.0
    @Published var isMuted: Bool = false

    @Published var outputDeviceName: String = ""

    @Published var cpuUsagePercentage: Int?
    @Published var diskAvailableBytes: Int64?
    @Published var diskTotalBytes: Int64?

    // MARK: Private

    private var timer: Timer?
    private let wifiClient = CWWiFiClient.shared()
    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "OpenIndicator.pathMonitor")
    private let locationManager = CLLocationManager()
    private var settingsObserver: AnyCancellable?

    private var previousCPUTicks: host_cpu_load_info_data_t?

    private var isOnline = false
    private var isOnWiFiInterface = false

    override init() {
        super.init()

        locationManager.delegate = self
        requestLocationIfNeeded()

        startPathMonitor()
        refreshAll()

        startTimer(interval: AppSettings.shared.refreshInterval)

        settingsObserver = AppSettings.shared.$refreshInterval
            .dropFirst()
            .sink { [weak self] interval in
                self?.startTimer(interval: interval)
            }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePowerStateChange),
            name: .NSProcessInfoPowerStateDidChange,
            object: nil
        )
    }

    @objc private func handlePowerStateChange() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    private func startTimer(interval: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refreshAll()
        }
    }

    deinit {
        timer?.invalidate()
        pathMonitor.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    func refreshAll() {
        refreshBattery()
        refreshWiFi()
        refreshVolume()
        refreshCPU()
        refreshDisk()
    }

    // MARK: Location permission (required for SSID + RSSI)

    private func requestLocationIfNeeded() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            wifiDetailsRestricted = true
        default:
            wifiDetailsRestricted = false
        }
    }

    // MARK: Reachability

    private func startPathMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let online = (path.status == .satisfied)
            let viaWiFi = path.usesInterfaceType(.wifi)
            DispatchQueue.main.async {
                self.isOnline = online
                self.isOnWiFiInterface = viaWiFi
                self.refreshWiFi()
            }
        }
        pathMonitor.start(queue: pathQueue)
    }

    // MARK: Battery

    private func refreshBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, first)?.takeUnretainedValue() as? [String: Any]
        else { return }

        if let capacity = description[kIOPSCurrentCapacityKey] as? Int,
           let max = description[kIOPSMaxCapacityKey] as? Int, max > 0 {
            batteryPercentage = Int((Double(capacity) / Double(max)) * 100.0)
        }

        if let state = description[kIOPSPowerSourceStateKey] as? String {
            isPluggedIn = (state == kIOPSACPowerValue)
        }

        if let charging = description[kIOPSIsChargingKey] as? Bool {
            isCharging = charging
        }

        checkLowBatteryAlert()

        let key = isCharging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey
        if let minutes = description[key] as? Int, minutes >= 0 {
            batteryMinutesRemaining = minutes
        } else {
            batteryMinutesRemaining = nil
        }

        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    // MARK: Wi-Fi

    private func refreshWiFi() {
        let interface = wifiClient.interface()
        let radioOn = interface?.powerOn() ?? false

        wifiConnected = radioOn && isOnWiFiInterface && isOnline

        guard let interface, wifiConnected else {
            wifiSignalBars = 0
            wifiRSSI = 0
            wifiTransmitRate = 0
            wifiChannel = 0
            wifiBand = ""
            wifiNoise = 0
            wifiSecurityType = ""
            wifiLocalIPAddress = ""
            wifiNetworkName = radioOn ? "Not connected" : "Wi-Fi off"
            return
        }

        if let ssid = interface.ssid(), !ssid.isEmpty {
            wifiNetworkName = ssid
            wifiDetailsRestricted = false
        } else {
            wifiNetworkName = "Connected"
            if locationManager.authorizationStatus == .denied
                || locationManager.authorizationStatus == .restricted {
                wifiDetailsRestricted = true
            }
        }

        let rssi = interface.rssiValue()
        let rate = interface.transmitRate()
        wifiRSSI = rssi
        wifiTransmitRate = rate

        wifiSignalBars = Self.bars(rssi: rssi, transmitRate: rate)

        wifiNoise = interface.noiseMeasurement()

        if let channel = interface.wlanChannel() {
            wifiChannel = channel.channelNumber
            switch channel.channelBand {
            case .band2GHz:  wifiBand = "2.4 GHz"
            case .band5GHz:  wifiBand = "5 GHz"
            case .band6GHz:  wifiBand = "6 GHz"
            default:         wifiBand = ""
            }
        } else {
            wifiChannel = 0
            wifiBand = ""
        }

        wifiSecurityType = Self.securityLabel(for: interface.security())
        wifiLocalIPAddress = Self.localIPv4Address(forInterfaceNamed: interface.interfaceName)
    }

    private static func securityLabel(for security: CWSecurity) -> String {
        switch security {
        case .none:                return "Open (no password)"
        case .WEP:                 return "WEP"
        case .wpaPersonal:         return "WPA Personal"
        case .wpaPersonalMixed:    return "WPA/WPA2 Personal"
        case .wpa2Personal:        return "WPA2 Personal"
        case .personal:            return "Personal"
        case .dynamicWEP:          return "Dynamic WEP"
        case .wpaEnterprise:       return "WPA Enterprise"
        case .wpaEnterpriseMixed:  return "WPA/WPA2 Enterprise"
        case .wpa2Enterprise:      return "WPA2 Enterprise"
        case .enterprise:          return "Enterprise"
        case .wpa3Personal:        return "WPA3 Personal"
        case .wpa3Enterprise:      return "WPA3 Enterprise"
        case .wpa3Transition:      return "WPA3 Transition"
        case .unknown:             fallthrough
        @unknown default:          return ""
        }
    }

    private static func localIPv4Address(forInterfaceNamed name: String?) -> String {
        guard let name else { return "" }

        var ifaddrPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPointer) == 0, let firstAddr = ifaddrPointer else { return "" }
        defer { freeifaddrs(ifaddrPointer) }

        var result = ""
        var pointer: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }

            let interface = current.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            guard addrFamily == UInt8(AF_INET) else { continue }
            guard String(cString: interface.ifa_name) == name else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let success = getnameinfo(
                interface.ifa_addr,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &hostname, socklen_t(hostname.count),
                nil, 0,
                NI_NUMERICHOST
            )
            if success == 0 {
                result = String(cString: hostname)
            }
            break
        }
        return result
    }

    static func bars(rssi: Int, transmitRate: Double) -> Int {
        if rssi != 0 {
            switch rssi {
            case (-55)...:    return 3
            case (-67)...(-56): return 2
            case (-80)...(-68): return 1
            default:          return 1
            }
        }
        if transmitRate > 0 {
            switch transmitRate {
            case 300...:   return 3
            case 100..<300: return 2
            default:       return 1
            }
        }
        return 1
    }

    // MARK: Volume

    private func refreshVolume() {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &size,
            &defaultOutputDeviceID
        )
        guard status == noErr else { return }

        var volumeValue = Float32(0)
        var volumeSize = UInt32(MemoryLayout<Float32>.size)
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        if AudioObjectHasProperty(defaultOutputDeviceID, &volumeAddress) {
            let volStatus = AudioObjectGetPropertyData(
                defaultOutputDeviceID, &volumeAddress, 0, nil, &volumeSize, &volumeValue
            )
            if volStatus == noErr {
                volume = Double(volumeValue)
            }
        } else {
            volumeAddress.mElement = 1
            if AudioObjectHasProperty(defaultOutputDeviceID, &volumeAddress) {
                let volStatus = AudioObjectGetPropertyData(
                    defaultOutputDeviceID, &volumeAddress, 0, nil, &volumeSize, &volumeValue
                )
                if volStatus == noErr {
                    volume = Double(volumeValue)
                }
            }
        }

        outputDeviceName = Self.deviceName(for: defaultOutputDeviceID)

        var muteValue = UInt32(0)
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(defaultOutputDeviceID, &muteAddress) {
            let mStatus = AudioObjectGetPropertyData(
                defaultOutputDeviceID, &muteAddress, 0, nil, &muteSize, &muteValue
            )
            if mStatus == noErr {
                isMuted = (muteValue == 1)
            }
        }
    }

    static func deviceName(for deviceID: AudioDeviceID) -> String {
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            deviceID, &address, 0, nil, &size, &name
        )
        guard status == noErr, let name else { return "" }

        return name.takeRetainedValue() as String
    }

    func toggleMute() {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var deviceIDSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var deviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let deviceStatus = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &deviceAddress, 0, nil,
            &deviceIDSize, &defaultOutputDeviceID
        )
        guard deviceStatus == noErr else { return }

        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(defaultOutputDeviceID, &muteAddress) else { return }

        var newValue: UInt32 = isMuted ? 0 : 1
        let setStatus = AudioObjectSetPropertyData(
            defaultOutputDeviceID, &muteAddress, 0, nil,
            UInt32(MemoryLayout<UInt32>.size), &newValue
        )
        guard setStatus == noErr else { return }

        isMuted = (newValue == 1)
    }

    // MARK: CPU

    private func refreshCPU() {
        var loadInfo = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        )

        let status = withUnsafeMutablePointer(to: &loadInfo) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPointer, &count)
            }
        }
        guard status == KERN_SUCCESS else { return }

        defer { previousCPUTicks = loadInfo }

        guard let previous = previousCPUTicks else { return }

        func ticks(_ info: host_cpu_load_info_data_t) -> (total: UInt32, idle: UInt32) {
            let user = info.cpu_ticks.0
            let system = info.cpu_ticks.1
            let idle = info.cpu_ticks.2
            let nice = info.cpu_ticks.3
            return (user &+ system &+ idle &+ nice, idle)
        }

        let previousTicks = ticks(previous)
        let currentTicks = ticks(loadInfo)

        let totalDelta = currentTicks.total &- previousTicks.total
        let idleDelta = currentTicks.idle &- previousTicks.idle

        guard totalDelta > 0 else { return }

        let usage = (Double(totalDelta - idleDelta) / Double(totalDelta)) * 100.0
        cpuUsagePercentage = Int(usage.rounded())
    }

    // MARK: Disk

    private func refreshDisk() {
        let rootURL = URL(fileURLWithPath: "/")
        guard let values = try? rootURL.resourceValues(
            forKeys: [.volumeAvailableCapacityKey, .volumeTotalCapacityKey]
        ) else {
            diskAvailableBytes = nil
            diskTotalBytes = nil
            return
        }
        diskAvailableBytes = values.volumeAvailableCapacity.map(Int64.init)
        diskTotalBytes = values.volumeTotalCapacity.map(Int64.init)
    }
}

// MARK: - Low battery notification

extension SystemMonitor {
    fileprivate func checkLowBatteryAlert() {
        guard AppSettings.shared.lowBatteryAlertsEnabled else { return }

        if isCharging || isPluggedIn {
            didSendLowBatteryAlert = false
            return
        }

        guard batteryPercentage <= lowBatteryThreshold else {
            didSendLowBatteryAlert = false
            return
        }

        guard !didSendLowBatteryAlert else { return }
        didSendLowBatteryAlert = true

        let content = UNMutableNotificationContent()
        content.title = "Low battery"
        content.body = "\(batteryPercentage)% remaining. Connect a charger soon."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "OpenIndicator.lowBattery",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - CLLocationManagerDelegate

extension SystemMonitor: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            wifiDetailsRestricted = true
        default:
            wifiDetailsRestricted = false
        }
        refreshWiFi()
    }
}
