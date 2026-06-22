import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleMute = Self("toggleMute", default: .init(.m, modifiers: [.control, .option, .command]))
}

enum HotkeyController {
    static func install() {
        KeyboardShortcuts.onKeyDown(for: .toggleMute) {
            Task { @MainActor in AudioController.shared.toggle() }
        }
    }
}
