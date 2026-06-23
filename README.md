# MuteKey

A tiny native macOS menu-bar app that toggles your microphone with a global hotkey.

The menu-bar icon turns **red** when muted, an optional on-screen HUD flashes the
state, and a Liquid Glass popover gives you a device picker and settings.

## Features

- **Global hotkey** to toggle mute (default ⌃⌥⌘M, configurable in the popover)
- **Push-to-talk** — assign a second hotkey to unmute only while it's held
- **Red menu-bar icon** when muted; adaptive monochrome mic when live
- **On-screen HUD** that flashes the muted/live glyph (toggleable)
- **Optional sound effects** on mute/unmute, with a volume slider (off by default)
- **Device targeting** — follow the system default input, target one specific
  mic, or mute **all** input devices at once
- Only real hardware mics are listed; virtual devices (e.g. Microsoft Teams
  Audio, ZoomAudioDevice) are filtered out
- **Launch at login**

## Requirements

- macOS 26 or later (the UI uses Liquid Glass / `glassEffect`)
- [Nix](https://nixos.org) with flakes enabled (for the reproducible build)

## Build & run

This is a SwiftPM project built through a Nix flake.

```sh
# Build → ./result/bin/MuteKey
nix build

# Build and run
nix run .
```

For faster local iteration, use the dev shell (or `direnv`, see below) and
SwiftPM directly:

```sh
nix develop
swift build
swift run MuteKey
```

> **Editor / LSP note:** the build SDK comes from the flake via `direnv`
> (`.envrc` → `use flake`). After changing `flake.nix` (e.g. the SDK), run
> `direnv reload` and restart your editor so sourcekit-lsp picks up the new
> `SDKROOT` — otherwise you'll see stale errors like
> `Value of type 'some View' has no member 'glassEffect'`.

## How it works

The mute primitive prefers `kAudioDevicePropertyMute` on the input scope. For
devices that don't expose it, it drives `kAudioDevicePropertyVolumeScalar` to 0
and restores the prior level on unmute. Muting the hardware input is what makes
mute work even with apps (like Teams) that ignore the per-device mute flag.

| File | Responsibility |
| --- | --- |
| `MuteKeyApp.swift` | App entry point; `MenuBarExtra` + menu-bar icon state. |
| `PopoverView.swift` | Liquid Glass popover: status, device picker, settings. |
| `AudioController.swift` | CoreAudio device enumeration, mute primitive, listeners. |
| `HotkeyController.swift` | Global toggle and push-to-talk hotkeys. |
| `HUDController.swift` | Borderless panel that flashes the muted/live glyph. |
| `SoundController.swift` | Plays bundled mute/unmute sounds when enabled. |
| `Settings.swift` | `UserDefaults`-backed prefs, shared with `@AppStorage`. |
