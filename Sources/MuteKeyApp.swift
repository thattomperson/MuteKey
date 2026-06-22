import SwiftUI

@main
struct MuteKeyApp: App {
    @State private var muted = true

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
        } label: {
            Image(systemName: muted ? "mic.slash.fill" : "mic.fill")
                // A template image so the menu bar tints it; SwiftUI handles
                // the rendering, including the red tint when muted.
                .foregroundStyle(muted ? Color.red : Color.primary)
        }
        .menuBarExtraStyle(.window)
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
        .frame(width: 280, height: 200, alignment: .topLeading)
        .glassEffect(in: .rect(cornerRadius: 16.0))
    }
}
