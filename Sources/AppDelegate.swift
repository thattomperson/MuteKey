import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 280, height: 200)
        popover.contentViewController = NSHostingController(rootView: PopoverView())

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
        let img = NSImage(
            systemSymbolName: symbol, accessibilityDescription: muted ? "Muted" : "Unmuted")
        img?.isTemplate = !muted
        statusItem.button?.image = img
        statusItem.button?.contentTintColor = muted ? .systemRed : nil
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard NSApp.currentEvent != nil else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            makePopoverTransparent()
            // Bring the popover to the front so it accepts input immediately.
            popover.contentViewController?.view.window?.makeKey()
            NSApp.activate()
        }
    }

    /// `NSPopover` paints an opaque material behind its content view, which
    /// washes out the SwiftUI glass effect. Walk up to the frame view and clear
    /// the material so the glass renders against what's behind the window.
    private func makePopoverTransparent() {
        guard let frameView = popover.contentViewController?.view.window?.contentView?.superview
        else { return }
        // The popover's background-drawing view is the frame view; remove its
        // material so only the SwiftUI glass shows.
        for subview in frameView.subviews where subview is NSVisualEffectView {
            (subview as? NSVisualEffectView)?.state = .inactive
            subview.isHidden = true
        }
    }
}

private struct PopoverView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MuteKey")
                .font(.headline)
            Divider()
            Text("Microphone controls go here.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassEffect(in: .rect(cornerRadius: 16.0))
    }
}
