import Foundation
import SwiftUI

enum TargetMode: String {
    case followDefault
    case specificDevice
    /// Mute/unmute every input device at once.
    case allDevices
}

/// `@AppStorage` requires its stored type to be `RawRepresentable` with a
/// `String`/`Int` raw value, so this conformance lets views bind a `TargetMode`
/// directly: `@AppStorage(Settings.Key.targetMode) var mode = TargetMode...`.
extension TargetMode: RawRepresentable {}

/// Backing store for app preferences.
///
/// `@AppStorage` and these accessors both read/write `UserDefaults.standard`
/// under the same keys, so SwiftUI views can use `@AppStorage` for live,
/// auto-persisting bindings while non-View code (e.g. `AudioController`, called
/// from CoreAudio listener contexts) reads the same values synchronously here.
enum Settings {
    enum Key {
        static let targetMode = "targetMode"
        static let targetDeviceUID = "targetDeviceUID"
        static let restoreLevels = "restoreLevelsByUID"
        static let hudEnabled = "hudEnabled"
        static let soundEnabled = "soundEnabled"
        static let soundVolume = "soundVolume"
    }

    /// Register non-false defaults. `@AppStorage("hudEnabled")` initializers
    /// supply their own default, but registering here keeps the synchronous
    /// `Settings.hudEnabled` accessor consistent with the views.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Key.hudEnabled: true,
            // Full volume by default; without this the synchronous accessor
            // would read 0.0 (silent) for users who never moved the slider.
            Key.soundVolume: 1.0,
        ])
    }

    static var hudEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Key.hudEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: Key.hudEnabled) }
    }

    /// Whether a sound effect plays on mute/unmute. No registered default, so it
    /// defaults to `false` — sound effects are opt-in.
    static var soundEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Key.soundEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: Key.soundEnabled) }
    }

    /// Playback volume for the mute/unmute sounds, 0...1. Defaults to 1.0
    /// (registered in `registerDefaults()`).
    static var soundVolume: Double {
        get { UserDefaults.standard.double(forKey: Key.soundVolume) }
        set { UserDefaults.standard.set(newValue, forKey: Key.soundVolume) }
    }

    static var targetMode: TargetMode {
        get {
            UserDefaults.standard.string(forKey: Key.targetMode)
                .flatMap(TargetMode.init(rawValue:)) ?? .followDefault
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Key.targetMode) }
    }

    static var targetDeviceUID: String? {
        get { UserDefaults.standard.string(forKey: Key.targetDeviceUID) }
        set { UserDefaults.standard.set(newValue, forKey: Key.targetDeviceUID) }
    }

    // Cache prior input volume per-device-UID for the volume-fallback path.
    static func restoreLevel(for uid: String) -> Float? {
        let dict = UserDefaults.standard.dictionary(forKey: Key.restoreLevels) ?? [:]
        return dict[uid] as? Float
    }

    static func setRestoreLevel(_ level: Float?, for uid: String) {
        var dict = UserDefaults.standard.dictionary(forKey: Key.restoreLevels) ?? [:]
        if let level { dict[uid] = level } else { dict.removeValue(forKey: uid) }
        UserDefaults.standard.set(dict, forKey: Key.restoreLevels)
    }
}
