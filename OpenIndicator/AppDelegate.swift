import AppKit
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var hostingView: NSHostingView<AnyView>!
    private let monitor = SystemMonitor()
    private let settings = AppSettings.shared

    private var barThickness: CGFloat { NSStatusBar.system.thickness }
    private var glyphSize: CGFloat { max(18, barThickness - 2) }

    private var itemWidth: CGFloat { glyphSize + 8 }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        setUpPopover()
        requestNotificationAuthorization()
    }

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error {
                NSLog("OpenIndicator: notification authorization error: \(error.localizedDescription)")
            }
        }
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: itemWidth)
        statusItem.behavior = [.terminationOnRemoval]

        guard let button = statusItem.button else {
            NSLog("OpenIndicator: status item has no button — cannot install glyph.")
            return
        }

        let width = itemWidth
        let height = barThickness

        let root = AnyView(
            RingMenuBarLabel(size: glyphSize)
                .environmentObject(monitor)
                .environmentObject(settings)
                .frame(width: width, height: height)
        )

        hostingView = NSHostingView(rootView: root)
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        // Let clicks fall through to the status item button underneath.
        hostingView.autoresizingMask = [.width, .height]
        button.addSubview(hostingView)

        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        NSLog("OpenIndicator: status item installed (bar %.0fpt, glyph %.0fpt).",
              barThickness, glyphSize)
    }

    private func setUpPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        popover.appearance = nil
        popover.delegate = self
        rebuildPopoverContent()
    }

    private func rebuildPopoverContent(initialScreen: RingPanelView.InitialScreen = .status) {
        let hosting = NSHostingController(
            rootView: RingPanelView(initialScreen: initialScreen)
                .environmentObject(monitor)
                .environmentObject(settings)
        )

        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
    }

    @objc private func handleClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            togglePopover(sender)
            return
        }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit OpenIndicator",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        menu.addItem(quitItem)

        guard let button = statusItem.button else { return }

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }

    @objc private func openSettingsFromMenu() {
        monitor.refreshAll()

        rebuildPopoverContent(initialScreen: .settings)
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            monitor.refreshAll()

            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

// NSPopoverDelegate

extension AppDelegate: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        rebuildPopoverContent()
    }
}
