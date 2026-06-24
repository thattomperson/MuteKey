// Renders the MuteKey app icon (muted MicGlyph look) to a 1024×1024 PNG.
//
// This mirrors PopoverView's MicGlyph in its muted state — a red mic.slash on a
// soft red field — but as a static drawing, because MicGlyph's `.glassEffect`
// is a live GPU material that ImageRenderer can't rasterize.
//
// Run via the dev shell; `Tools/generate-icon.sh` wraps this and produces the
// committed AppIcon.icns:
//   nix develop --command swift Tools/GenerateIcon.swift <output.png>

import SwiftUI
import AppKit

private struct IconView: View {
    var body: some View {
        // Matches Accent.tint(muted:) == .red, as a gradient for some depth.
        let red = Color(red: 0.95, green: 0.27, blue: 0.27)
        ZStack {
            // Full-bleed canvas; macOS masks the rounded-rect corners itself.
            LinearGradient(
                colors: [red.opacity(0.95), red.opacity(0.70)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            // Inset the glyph ~15% so it reads like a standard macOS icon
            // rather than edge-to-edge.
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 480, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 1024, height: 1024)
    }
}

@MainActor
private func render(to path: String) {
    let renderer = ImageRenderer(content: IconView())
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

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
MainActor.assumeIsolated { render(to: outPath) }
