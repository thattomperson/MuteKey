// Renders the MuteKey app icon (muted MicGlyph look) to a square PNG.
//
// This mirrors PopoverView's MicGlyph in its muted state — a red mic.slash on a
// soft red field — but as a static drawing, because MicGlyph's `.glassEffect`
// is a live GPU material that ImageRenderer can't rasterize.
//
// Usage: GenerateIcon <size> <output.png>
// The `icon` flake package renders each size and packs them into AppIcon.icns
// with png2icns (`nix build .#icon`).

import SwiftUI
import AppKit

private struct IconView: View {
    let size: CGFloat
    var body: some View {
        // Matches Accent.tint(muted:) == .red, as a gradient for some depth.
        let red = Color(red: 0.95, green: 0.27, blue: 0.27)
        // macOS 26 frames every .icns in its own rounded-rect plate regardless,
        // so we draw a matching rounded-rect plate (~22.4% radius ≈ the macOS
        // squircle) — it reads as intentional inside the system frame rather
        // than a sharp-cornered square floating in it.
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.224, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [red.opacity(0.95), red.opacity(0.70)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "mic.slash.fill")
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

@MainActor
private func render(size: CGFloat, to path: String) {
    let renderer = ImageRenderer(content: IconView(size: size))
    renderer.scale = 1.0
    guard let cg = renderer.cgImage else { fputs("error: ImageRenderer produced no image\n", stderr); exit(1) }
    let rep = NSBitmapImageRep(cgImage: cg)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fputs("error: could not encode PNG\n", stderr); exit(1)
    }
    do {
        try png.write(to: URL(fileURLWithPath: path))
        print("wrote \(path) (\(cg.width)x\(cg.height))")
    } catch {
        fputs("error: \(error)\n", stderr); exit(1)
    }
}

guard CommandLine.arguments.count == 3, let size = Double(CommandLine.arguments[1]) else {
    fputs("usage: GenerateIcon <size> <output.png>\n", stderr); exit(2)
}
MainActor.assumeIsolated { render(size: CGFloat(size), to: CommandLine.arguments[2]) }
