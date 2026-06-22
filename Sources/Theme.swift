import SwiftUI

enum Theme {
    static let bgTop = Color(red: 0x3B/255.0, green: 0x2A/255.0, blue: 0x78/255.0)
    static let bgBottom = Color(red: 0x6E/255.0, green: 0x5B/255.0, blue: 0xFF/255.0)
    static let live = Color(red: 0x34/255.0, green: 0xD3/255.0, blue: 0x99/255.0)
    static let muted = Color(red: 0xF8/255.0, green: 0x71/255.0, blue: 0x71/255.0)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.65)
    static let surface = Color.white.opacity(0.06)
    static let stroke = Color.white.opacity(0.10)

    static let gradient = LinearGradient(
        colors: [bgTop, bgBottom],
        startPoint: .top,
        endPoint: .bottom
    )

    static let releasesURL = URL(string: "https://github.com/billimek/muteapp/releases")!
}
