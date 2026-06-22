import AppKit
import SwiftUI

@MainActor
final class HUDController {
    static let shared = HUDController()

    private var panel: NSPanel?
    private var hideWorkItem: DispatchWorkItem?

    func flash(muted: Bool) {
        guard Settings.hudEnabled else { return }

        let panel = panel ?? makePanel()
        self.panel = panel

        let hosting = NSHostingView(rootView: HUDView(muted: muted))
        hosting.frame = panel.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        panel.contentView?.subviews.forEach { $0.removeFromSuperview() }
        panel.contentView?.addSubview(hosting)

        positionOnCursorScreen(panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 1.0
        }

        hideWorkItem?.cancel()
        let work = DispatchWorkItem { [weak panel] in
            guard let panel else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
            })
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65, execute: work)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 220),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.contentView = NSView(frame: panel.contentRect(forFrameRect: panel.frame))
        return panel
    }

    private func positionOnCursorScreen(_ panel: NSPanel) {
        let cursor = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSPointInRect(cursor, $0.frame) }) ?? NSScreen.main
        guard let screen else { return }
        let f = screen.frame
        let size = panel.frame.size
        let origin = NSPoint(
            x: f.midX - size.width / 2,
            y: f.midY - size.height / 2
        )
        panel.setFrameOrigin(origin)
    }
}

private struct HUDView: View {
    let muted: Bool

    var body: some View {
        let tint = muted ? Color.red : Color.green
        VStack(spacing: 12) {
            Image(systemName: muted ? "mic.slash.fill" : "mic.fill")
                .font(.system(size: 110, weight: .semibold))
                .foregroundStyle(tint)
            Text(muted ? "Muted" : "Live")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: 220, height: 220)
        .glassEffect(.regular.tint(tint.opacity(0.2)), in: .rect(cornerRadius: 28))
    }
}
