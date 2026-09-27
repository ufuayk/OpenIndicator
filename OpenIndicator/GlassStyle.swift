import SwiftUI
import AppKit

extension View {

    func panelSection(cornerRadius: CGFloat = 12) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.quinary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5)
            )
    }

    @ViewBuilder
    func liquidGlassCapsule() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: .capsule)
        } else {
            self
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
        }
    }
}

final class AppearancePreferences: ObservableObject {
    static let shared = AppearancePreferences()

    @Published var reduceTransparency: Bool

    private var observerToken: NSObjectProtocol?

    private init() {
        reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency

        observerToken = NotificationCenter.default.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reduceTransparency =
                NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        }
    }

    deinit {
        if let observerToken {
            NotificationCenter.default.removeObserver(observerToken)
        }
    }
}
