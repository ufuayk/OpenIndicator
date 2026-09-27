import SwiftUI

struct RingIcon: View {

    var volume: Double        // 0.0 ... 1.0
    var isMuted: Bool
    var batteryLevel: Int     // 0 ... 100

    var isCharging: Bool
    var signalBars: Int       // 0 ... 3
    var wifiConnected: Bool
    var size: CGFloat

    var showBattery: Bool = true
    var showWifi: Bool = true
    var showVolume: Bool = true

    private let trackSweep: Double = 0.75
    private let trackRotation: Double = 135

    private var scale: CGFloat { size / 100 }

    private var batteryColor: Color {
        .primary
    }

    private var volumeDotsLit: Int {
        isMuted ? 0 : max(volume > 0 ? 1 : 0, Int(ceil(volume / 0.25)))
    }

    private var volumeColor: Color {
        isMuted ? .secondary : .primary
    }

    var body: some View {
        ZStack {
            if showBattery { batteryRing }
            if showWifi { wifiGlyph }
            if showVolume { volumeDots }
        }
        .frame(width: size, height: size)
    }

    // Outer ring — battery

    private var batteryRing: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: trackSweep)
                .stroke(
                    batteryColor.opacity(0.3),
                    style: StrokeStyle(lineWidth: 12 * scale, lineCap: .round)
                )
                .rotationEffect(.degrees(trackRotation))

            Circle()
                .trim(from: 0, to: trackSweep * max(0, min(1, Double(batteryLevel) / 100.0)))
                .stroke(
                    batteryColor,
                    style: StrokeStyle(lineWidth: 12 * scale, lineCap: .round)
                )
                .rotationEffect(.degrees(trackRotation))
                .animation(.easeInOut(duration: 0.3), value: batteryLevel)
        }
        .padding(4 * scale)
    }

    // Center — Wi-Fi signal

    private var wifiGlyph: some View {
        let radii: [CGFloat] = [14, 24, 34]

        return ZStack {
            ForEach(Array(radii.enumerated()), id: \.offset) { index, radius in
                WifiArc(radius: radius * scale)
                    .stroke(
                        arcColor(for: index),
                        style: StrokeStyle(lineWidth: 7 * scale, lineCap: .round)
                    )
                    .animation(.easeInOut(duration: 0.3), value: signalBars)
            }

            Circle()
                .fill(wifiConnected ? Color.primary : Color.secondary.opacity(0.55))
                .frame(width: 8 * scale, height: 8 * scale)
                .position(x: 50 * scale, y: 64 * scale)

            if !wifiConnected {
                Rectangle()
                    .fill(Color.secondary)
                    .frame(width: 52 * scale, height: 5 * scale)
                    .rotationEffect(.degrees(-45))
                    .position(x: 50 * scale, y: 46 * scale)
            }
        }
        .frame(width: 100 * scale, height: 100 * scale)
        .offset(y: 2 * scale)
    }

    private func arcColor(for index: Int) -> Color {
        guard wifiConnected else { return .secondary.opacity(0.35) }
        return index < signalBars ? .primary : .primary.opacity(0.32)
    }

    private struct WifiArc: Shape {
        let radius: CGFloat

        func path(in rect: CGRect) -> Path {
            var path = Path()
            let center = CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.14)
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(218),
                endAngle: .degrees(322),
                clockwise: false
            )
            return path
        }
    }

    // volume dots

    private var volumeDots: some View {
        HStack(spacing: 5 * scale) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(
                        index < volumeDotsLit
                            ? volumeColor
                            : Color.primary.opacity(0.3)
                    )
                    .frame(width: 9 * scale, height: 9 * scale)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: volumeDotsLit)
        .frame(width: 100 * scale, height: 100 * scale, alignment: .bottom)
        .padding(.bottom, 1 * scale)
    }
}

#Preview {
    HStack(spacing: 30) {
        RingIcon(volume: 0.7, isMuted: false, batteryLevel: 80, isCharging: false,
                 signalBars: 3, wifiConnected: true, size: 120)
        RingIcon(volume: 0.3, isMuted: false, batteryLevel: 40, isCharging: true,
                 signalBars: 1, wifiConnected: true, size: 120)
        RingIcon(volume: 0.0, isMuted: true, batteryLevel: 10, isCharging: false,
                 signalBars: 0, wifiConnected: false, size: 120)
    }
    .padding(40)
}
