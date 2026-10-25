import SwiftUI

/// The app's design system. Classic is the Windows 2000 look from the design mockups: grey
/// bevelled chrome, a blue gradient title bar, sunken white wells and dithered pressed-in
/// toggles, with colours sampled from the mockups. Y2K Chrome swaps in pink iridescent glass
/// and liquid-chrome lettering. Every colour and font here follows the theme picked on the
/// Profile tab, so any view that reads one redraws when it changes.
enum Win95 {
    static var theme: AppTheme { ThemeStore.shared.theme }
    static var isChrome: Bool { theme == .chrome }
    static var palette: Win95Palette { theme.palette }

    // MARK: Colours

    /// Window and button grey.
    static var face: Color { palette.face }
    /// Top-left edge of raised things, bottom-right edge of sunken things.
    static var highlight: Color { palette.highlight }
    /// The softer inner edge next to `highlight`.
    static var light: Color { palette.light }
    /// Inner shadow edge.
    static var shadow: Color { palette.shadow }
    /// Outer shadow edge.
    static var darkShadow: Color { palette.darkShadow }
    /// The inside of text fields and list boxes.
    static var window: Color { palette.window }
    static var text: Color { palette.text }
    static var secondaryText: Color { palette.secondaryText }
    static var disabledText: Color { palette.disabledText }
    /// Title bar start, and the selected tab's icon and label. Hot pink in Y2K Chrome.
    static var navy: Color { palette.navy }
    /// Title bar end.
    static var sky: Color { palette.sky }
    static var heart: Color { palette.heart }
    static var tooltip: Color { palette.tooltip }
    /// The two halves of the checkerboard on a pressed-in toggle: white and face grey, as Windows draws it.
    static var ditherLight: Color { palette.ditherLight }
    static var ditherDark: Color { palette.ditherDark }

    // MARK: Shape

    /// Square corners in Classic, rounded glass in Y2K Chrome.
    static var cornerRadius: CGFloat { isChrome ? Chrome.cornerRadius : 0 }

    // MARK: Type

    /// Verdana, the closest font iOS ships to Windows' Tahoma, or Avenir Next for Y2K Chrome.
    /// Scales with Dynamic Type.
    static func font(_ size: CGFloat, bold: Bool = false, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(fontName(for: theme, bold: bold), size: size, relativeTo: style)
    }

    static func fontName(for theme: AppTheme, bold: Bool) -> String {
        switch theme {
        case .classic: bold ? "Verdana-Bold" : "Verdana"
        case .chrome: bold ? "AvenirNext-Bold" : "AvenirNext-Medium"
        }
    }
}

/// Every colour one theme draws with. See `Win95` for what each one is for.
struct Win95Palette: Equatable {
    var face: Color
    var highlight: Color
    var light: Color
    var shadow: Color
    var darkShadow: Color
    var window: Color
    var text: Color
    var secondaryText: Color
    var disabledText: Color
    var navy: Color
    var sky: Color
    var heart: Color
    var tooltip: Color
    var ditherLight: Color
    var ditherDark: Color

    static let classic = Win95Palette(
        face: Color(win95Hex: 0xD4D0C8),
        highlight: .white,
        light: Color(win95Hex: 0xDFDFDF),
        shadow: Color(win95Hex: 0x808080),
        darkShadow: Color(win95Hex: 0x404040),
        window: .white,
        text: .black,
        secondaryText: Color(win95Hex: 0x404040),
        disabledText: Color(win95Hex: 0x808080),
        navy: Color(win95Hex: 0x0A246A),
        sky: Color(win95Hex: 0xA6CAF0),
        heart: Color(win95Hex: 0xCE1B4E),
        tooltip: Color(win95Hex: 0xFFFFE1),
        ditherLight: .white,
        ditherDark: Color(win95Hex: 0xD4D0C8)
    )

    /// Pearl and lilac glass with deep indigo text. The dither pair is the candy pink of a
    /// pressed-in toggle, top to bottom.
    static let chrome = Win95Palette(
        face: Color(win95Hex: 0xF6EEFF),
        highlight: .white,
        light: Color(win95Hex: 0xFBF7FF),
        shadow: Color(win95Hex: 0xB3A6DE),
        darkShadow: Color(win95Hex: 0x6F60AB),
        window: Color(win95Hex: 0xFFFFFF, opacity: 0.5),
        text: Color(win95Hex: 0x2B1F5C),
        secondaryText: Color(win95Hex: 0x5E4F93),
        disabledText: Color(win95Hex: 0x9C90C4),
        navy: Color(win95Hex: 0xB0126A),
        sky: Color(win95Hex: 0xA8DDFF),
        heart: Color(win95Hex: 0xFF2E93),
        tooltip: .white,
        ditherLight: Color(win95Hex: 0xFFE0F2),
        ditherDark: Color(win95Hex: 0xFFCCE9)
    )
}

extension AppTheme {
    var palette: Win95Palette {
        switch self {
        case .classic: .classic
        case .chrome: .chrome
        }
    }
}

extension Color {
    init(win95Hex hex: UInt32, opacity: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
