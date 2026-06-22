import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleMute = Self("toggleMute", default: .init(.m, modifiers: [.control, .option, .command]))

    /// Push-to-talk hotkey. Has no default; assigning it enables push-to-talk,
    /// clearing it disables the mode.
    static let pushToTalk = Self("pushToTalk")
}

enum HotkeyController {
    /// Tracks whether the push-to-talk key is currently held, so key auto-repeat
    /// (repeated key-down events) doesn't re-trigger the unmute.
    @MainActor private static var isTalking = false

    /// Registers the global hotkey handlers.
    ///
    /// The toggle hotkey flips the mute state on key down. The push-to-talk
    /// hotkey, when assigned, unmutes while held and re-mutes on release.
    static func install() {
        KeyboardShortcuts.onKeyDown(for: .toggleMute) {
            Task { @MainActor in AudioController.shared.toggle() }
        }

        KeyboardShortcuts.onKeyDown(for: .pushToTalk) {
            Task { @MainActor in
                guard !isTalking else { return }
                isTalking = true
                AudioController.shared.setMutedState(false)
            }
        }
        KeyboardShortcuts.onKeyUp(for: .pushToTalk) {
            Task { @MainActor in
                isTalking = false
                AudioController.shared.setMutedState(true)
            }
        }
    }
}
