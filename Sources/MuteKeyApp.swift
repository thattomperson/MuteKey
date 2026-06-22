import SwiftUI

@main
struct MuteKeyApp: App {
    @StateObject private var menuState = MenuBarState()

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
        } label: {
            Image(systemName: menuState.muted ? "mic.slash.fill" : "mic.fill")
                .foregroundStyle(menuState.muted ? Color.red : Color.primary)
        }
        .menuBarExtraStyle(.window)
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
            }
        }
    }

    isolated deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }
}
