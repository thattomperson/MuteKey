import KeyboardShortcuts
import ServiceManagement
import SwiftUI

@MainActor
final class PopoverModel: ObservableObject {
    @Published var muted: Bool = false
    @Published var devices: [InputDevice] = []
    @Published var targetMode: TargetMode = .followDefault
    @Published var targetUID: String? = nil
    @Published var launchAtLogin: Bool = (SMAppService.mainApp.status == .enabled)

    private var observers: [NSObjectProtocol] = []

    init() {
        refreshFromSettings()
        refreshDevices()
        muted = AudioController.shared.currentMuted()

        let nc = NotificationCenter.default
        observers.append(
            nc.addObserver(forName: .muteStateChanged, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.muted = AudioController.shared.currentMuted() }
            })
        observers.append(
            nc.addObserver(forName: .inputDevicesChanged, object: nil, queue: .main) {
                [weak self] _ in
                Task { @MainActor in
                    self?.refreshDevices()
                    self?.refreshFromSettings()
                }
            })
    }

    isolated deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func refreshDevices() {
        devices = AudioController.shared.listInputDevices()
    }

    func refreshFromSettings() {
        targetMode = Settings.targetMode
        targetUID = Settings.targetDeviceUID
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
    }

    func toggleMute() {
        AudioController.shared.toggle()
    }

    func selectFollowDefault() {
        Settings.targetMode = .followDefault
        Settings.targetDeviceUID = nil
        AudioController.shared.installMuteListenerForCurrentTarget()
        refreshFromSettings()
        muted = AudioController.shared.currentMuted()
    }

    func selectAllDevices() {
        Settings.targetMode = .allDevices
        Settings.targetDeviceUID = nil
        AudioController.shared.installMuteListenerForCurrentTarget()
        refreshFromSettings()
        muted = AudioController.shared.currentMuted()
    }

    func selectDevice(_ uid: String) {
        Settings.targetMode = .specificDevice
        Settings.targetDeviceUID = uid
        AudioController.shared.installMuteListenerForCurrentTarget()
        refreshFromSettings()
        muted = AudioController.shared.currentMuted()
    }

    func setLaunchAtLogin(_ value: Bool) {
        let svc = SMAppService.mainApp
        do {
            if value { try svc.register() } else { try svc.unregister() }
        } catch {
            NSLog("muteapp: launch-at-login toggle failed: \(error)")
        }
        launchAtLogin = (svc.status == .enabled)
    }
}

// MARK: - Shared constants

/// The two semantic accent colors and the one external URL that used to live in
/// Theme. Everything else is now system-driven (Liquid Glass + .primary/.secondary),
/// so it adapts to light/dark and vibrancy automatically.
enum Accent {
    static func tint(muted: Bool) -> Color { muted ? .red : .green }
    static let releasesURL = URL(string: "https://github.com/billimek/muteapp/releases")!
}

// MARK: - Root

struct PopoverView: View {
    @StateObject var model = PopoverModel()

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 14) {
                MicGlyph(muted: model.muted)
                    .padding(.top, 8)

                VStack(spacing: 2) {
                    Text(model.muted ? "Muted" : "Live")
                        .font(.title3.bold())
                        .foregroundStyle(Accent.tint(muted: model.muted))
                    Text(model.muted ? "Microphone is muted" : "Microphone is active")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                MuteButton(muted: model.muted) { model.toggleMute() }

                SectionHeader("INPUT DEVICE")
                DeviceList(model: model)

                SectionHeader("SETTINGS")
                SettingsRows(model: model)

                Footer()
                    .padding(.top, 4)
            }
            .padding(16)
        }
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Subviews

private struct MicGlyph: View {
    let muted: Bool
    var body: some View {
        let tint = Accent.tint(muted: muted)
        Image(systemName: muted ? "mic.slash.fill" : "mic.fill")
            .font(.system(size: 30, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 76, height: 76)
            .glassEffect(.regular.tint(tint.opacity(0.25)), in: .circle)
            .animation(.easeInOut(duration: 0.18), value: muted)
    }
}

private struct MuteButton: View {
    let muted: Bool
    let action: () -> Void
    var body: some View {
        let tint = Accent.tint(muted: muted)
        Button(action: action) {
            HStack {
                Image(systemName: muted ? "mic.fill" : "mic.slash.fill")
                Text(muted ? "Unmute" : "Mute")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                if let s = KeyboardShortcuts.getShortcut(for: .toggleMute) {
                    Text(s.description)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            // Vivid colored text/icon over a subtle glass tint, matching the
            // MicGlyph treatment instead of a solid saturated fill.
            .foregroundStyle(tint)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(tint.opacity(0.25)), in: .capsule)
    }
}

private struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

/// A glass-backed card that groups rows, with dividers between them.
private struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .glassEffect(in: .rect(cornerRadius: 12))
    }
}

private struct DeviceList: View {
    @ObservedObject var model: PopoverModel
    var body: some View {
        Card {
            DeviceRow(
                icon: "dot.radiowaves.left.and.right",
                name: "Follow current default",
                selected: model.targetMode == .followDefault
            ) { model.selectFollowDefault() }

            Divider()
            DeviceRow(
                icon: "mic.and.signal.meter",
                name: "All devices",
                selected: model.targetMode == .allDevices
            ) { model.selectAllDevices() }

            ForEach(model.devices, id: \.uid) { dev in
                Divider()
                DeviceRow(
                    icon: deviceIcon(name: dev.name),
                    name: dev.name,
                    selected: model.targetMode == .specificDevice && model.targetUID == dev.uid
                ) { model.selectDevice(dev.uid) }
            }
        }
    }

    private func deviceIcon(name: String) -> String {
        let lc = name.lowercased()
        if lc.contains("airpod") || lc.contains("headphone") || lc.contains("headset")
            || lc.contains("beats")
        {
            return "headphones"
        }
        if lc.contains("macbook") || lc.contains("imac") || lc.contains("built") {
            return "laptopcomputer"
        }
        return "mic"
    }
}

private struct DeviceRow: View {
    let icon: String
    let name: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 18)
                    .foregroundStyle(.secondary)
                Text(name)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsRows: View {
    @ObservedObject var model: PopoverModel
    @AppStorage(Settings.Key.hudEnabled) private var hudEnabled = true
    var body: some View {
        Card {
            HStack {
                Image(systemName: "command")
                    .frame(width: 18)
                    .foregroundStyle(.secondary)
                Text("Hotkey")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                Spacer()
                KeyboardShortcuts.Recorder(for: .toggleMute)
                    .controlSize(.small)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 12)

            Divider()

            // Bound straight to UserDefaults via @AppStorage; HUDController reads
            // the same `hudEnabled` key, so no model plumbing is needed.
            ToggleRow(
                icon: "rectangle.center.inset.filled",
                title: "Show on-screen HUD",
                isOn: $hudEnabled
            )

            Divider()

            ToggleRow(
                icon: "power",
                title: "Launch at Login",
                isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                )
            )
        }
    }
}

private struct ToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 18)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
    }
}

private struct Footer: View {
    var body: some View {
        HStack {
            Button {
                NSWorkspace.shared.open(Accent.releasesURL)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.down.circle")
                    Text("Check for Updates")
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(versionLabel)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                HStack(spacing: 4) {
                    Text("Quit")
                    Text("⌘Q").foregroundStyle(.tertiary)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
        }
    }

    private var versionLabel: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "v\(v)"
    }
}
