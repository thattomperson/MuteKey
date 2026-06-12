import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        refreshIcon()

        NSApp.setActivationPolicy(.accessory)
        NSApp.activate()
    }

    @objc private func refreshIcon() {
        let muted = true
        let symbol = muted ? "mic.slash.fill" : "mic.fill"
        let img = NSImage(systemSymbolName: symbol, accessibilityDescription: muted ? "Muted" : "Unmuted")
        img?.isTemplate = !muted
        statusItem.button?.image = img
        statusItem.button?.contentTintColor = muted ? .systemRed : nil
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard NSApp.currentEvent != nil else { return }
    }
}
