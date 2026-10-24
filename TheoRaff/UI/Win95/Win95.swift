import SwiftUI

/// The Windows 2000 "classic" look from the design mockups: grey bevelled chrome, a blue
/// gradient title bar, sunken white wells and dithered pressed-in toggles.
/// Colours are sampled from the mockups.
enum Win95 {
    // MARK: Colours

    /// Window and button grey.
    static let face = Color(win95Hex: 0xD4D0C8)
    /// Top-left edge of raised things, bottom-right edge of sunken things.
    static let highlight = Color.white
    /// The softer inner edge next to `highlight`.
    static let light = Color(win95Hex: 0xDFDFDF)
    /// Inner shadow edge.
    static let shadow = Color(win95Hex: 0x808080)
    /// Outer shadow edge.
    static let darkShadow = Color(win95Hex: 0x404040)
    /// The inside of text fields and list boxes.
    static let window = Color.white
    static let text = Color.black
    static let secondaryText = Color(win95Hex: 0x404040)
    static let disabledText = Color(win95Hex: 0x808080)
    /// Title bar start, and the selected tab's icon and label.
    static let navy = Color(win95Hex: 0x0A246A)
    /// Title bar end.
    static let sky = Color(win95Hex: 0xA6CAF0)
    static let heart = Color(win95Hex: 0xCE1B4E)
    static let tooltip = Color(win95Hex: 0xFFFFE1)
    /// The two halves of the checkerboard on a pressed-in toggle: white and face grey, as Windows draws it.
    static let ditherLight = Color.white
    static let ditherDark = Color(win95Hex: 0xD4D0C8)

    // MARK: Type

    /// Verdana, the closest font iOS ships to Windows' Tahoma. Scales with Dynamic Type.
    static func font(_ size: CGFloat, bold: Bool = false, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(bold ? "Verdana-Bold" : "Verdana", size: size, relativeTo: style)
    }
}

private extension Color {
    init(win95Hex hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
