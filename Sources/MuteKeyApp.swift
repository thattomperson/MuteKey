import SwiftUI

@main
struct MuteKeyApp: App {
    @StateObject private var menuState = MenuBarState()

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
        } label: {
            // MenuBarExtra renders its label as a template image, so SwiftUI's
            // .foregroundStyle/.renderingMode are ignored. Supply a non-template
            // NSImage with an explicit palette color so muted shows red.
            Image(nsImage: menuBarIcon(muted: menuState.muted))
        }
        .menuBarExtraStyle(.window)
    }

    /// Renders the menu-bar mic glyph as an `NSImage`.
    ///
    /// When muted we tint it red via a palette `SymbolConfiguration` and mark it
    /// non-template so macOS keeps the color. When live we leave it as a template
    /// image so it adapts to the menu bar's appearance like a normal status icon.
    private func menuBarIcon(muted: Bool) -> NSImage {
        let symbol = muted ? "mic.slash.fill" : "mic.fill"
        let base = NSImage(systemSymbolName: symbol, accessibilityDescription: muted ? "Muted" : "Live")
            ?? NSImage()

        guard muted else {
            base.isTemplate = true
            return base
        }

        let config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
        let colored = base.withSymbolConfiguration(config) ?? base
        colored.isTemplate = false
        return colored
    }
}

/// Drives the menu bar icon from the live mute state and installs the global
/// hotkey. Replaces the old AppDelegate's launch wiring.
@MainActor
final class MenuBarState: ObservableObject {
    @Published var muted: Bool = AudioController.shared.currentMuted()

    private var observer: NSObjectProtocol?

    init() {
        Settings.registerDefaults()

        // MenuBarExtra apps are accessory by default, but set it explicitly so
        // there's no Dock icon regardless of how the bundle is launched.
        NSApp.setActivationPolicy(.accessory)

        HotkeyController.install()

        observer = NotificationCenter.default.addObserver(
            forName: .muteStateChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                let muted = AudioController.shared.currentMuted()
                self?.muted = muted
                HUDController.shared.flash(muted: muted)
                SoundController.shared.play(muted: muted)
            }
        }
    }

    isolated deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }
}
