import SwiftUI

/// The pieces of the Y2K Chrome theme that have no Classic equivalent: polished rims,
/// candy and pearl fills, liquid lettering, sparkles and the iridescent backdrop.
enum Chrome {
    static let cornerRadius: CGFloat = 16

    /// Deep indigo, for the dark edge under chrome lettering.
    static let ink = Color(win95Hex: 0x2B1F5C)
    /// The soft pink haze round lettering and sparkles.
    static let glow = Color(win95Hex: 0xFF7CC4, opacity: 0.55)
    /// The lilac shadow under raised glass.
    static let shadowTint = Color(win95Hex: 0x7A63C9, opacity: 0.28)

    /// A polished silver rim catching pink and blue light, for buttons and panels.
    static let rim = AngularGradient(
        colors: [
            .white, Color(win95Hex: 0xC9C2EA), .white, Color(win95Hex: 0xFFB3DA),
            Color(win95Hex: 0xB5E0FF), .white, Color(win95Hex: 0xCDBFF5), .white,
        ],
        center: .center
    )
    /// The rim of a sunken well: shaded along the top, lit along the bottom.
    static let wellRim = LinearGradient(
        colors: [Color(win95Hex: 0x9F90D6, opacity: 0.9), .white],
        startPoint: .top,
        endPoint: .bottom
    )

    /// A hairline under a dialog's caption.
    static let divider = LinearGradient(
        colors: [Color(win95Hex: 0xB3A6DE, opacity: 0), Color(win95Hex: 0xFF9ACF), Color(win95Hex: 0xB3A6DE), Color(win95Hex: 0x9FD3FF), Color(win95Hex: 0xB3A6DE, opacity: 0)],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// A button at rest, top to bottom.
    static let pearlColours = [Color.white, Color(win95Hex: 0xEFE4FF)]
    static let pearl = LinearGradient(colors: pearlColours, startPoint: .top, endPoint: .bottom)
    /// A button pressed in or switched on, and the selected tab.
    static let candy = LinearGradient(
        colors: [Win95Palette.chrome.ditherLight, Win95Palette.chrome.ditherDark],
        startPoint: .top,
        endPoint: .bottom
    )
    /// The gloss across the top half of a button.
    static let sheen = LinearGradient(colors: [.white.opacity(0.85), .white.opacity(0)], startPoint: .top, endPoint: .center)
    /// Raised pearl: panels, dialogs and the tab bar, top to bottom. Opaque, so dialogs stay
    /// readable over busy screens.
    static let panelColours = [Color.white, Color(win95Hex: 0xF4EAFF)]
    static let panel = LinearGradient(colors: panelColours, startPoint: .top, endPoint: .bottom)
    /// The frosted glass inside a group box.
    static let groupFill = Color.white.opacity(0.4)
    /// The iridescent backdrop's 3 x 3 mesh, row by row: pink, lilac, blue, pearl and mint.
    static let backdropColours = [
        Color(win95Hex: 0xFFD3EC), Color(win95Hex: 0xEEDCFF), Color(win95Hex: 0xCFE6FF),
        Color(win95Hex: 0xE3D6FF), Color(win95Hex: 0xFFF4FB), Color(win95Hex: 0xFFD0E8),
        Color(win95Hex: 0xCFF5E7), Color(win95Hex: 0xDCD2FF), Color(win95Hex: 0xFFE1F2),
    ]
    static let heart = LinearGradient(
        colors: [Color(win95Hex: 0xFF8DCB), Win95Palette.chrome.heart],
        startPoint: .top,
        endPoint: .bottom
    )
    /// Liquid chrome: bright, a dark horizon line through the middle, then bright again.
    static let liquid = LinearGradient(
        stops: [
            .init(color: .white, location: 0),
            .init(color: Color(win95Hex: 0xE4DEF8), location: 0.3),
            .init(color: Color(win95Hex: 0x8D82C4), location: 0.47),
            .init(color: Color(win95Hex: 0x4E428C), location: 0.53),
            .init(color: Color(win95Hex: 0xD9D2F5), location: 0.68),
            .init(color: .white, location: 0.85),
            .init(color: Color(win95Hex: 0xF5B8DD), location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

/// Title lettering in liquid chrome, edged in ink all the way round so it reads on pale
/// glass. Plain ink when Increase Contrast is on.
struct ChromeLettering: View {
    let text: String
    let size: CGFloat

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let lettering = Text(text).font(.system(size: size, weight: .black, design: .rounded))
        if contrast == .increased {
            lettering.foregroundStyle(Chrome.ink)
        } else {
            lettering
                .foregroundStyle(Chrome.liquid)
                .shadow(color: Chrome.ink, radius: 0, x: 1, y: 0)
                .shadow(color: Chrome.ink, radius: 0, x: -1, y: 0)
                .shadow(color: Chrome.ink, radius: 0, x: 0, y: 1)
                .shadow(color: Chrome.ink, radius: 0, x: 0, y: -1)
                .shadow(color: Chrome.ink.opacity(0.45), radius: 0, x: 0, y: 2.5)
                .shadow(color: Chrome.glow, radius: 6)
        }
    }
}

/// A four-pointed twinkle.
struct ChromeSparkle: Shape {
    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let pinchX = rect.width * 0.09
        let pinchY = rect.height * 0.09
        var path = Path()
        path.move(to: CGPoint(x: centre.x, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: centre.y), control: CGPoint(x: centre.x + pinchX, y: centre.y - pinchY))
        path.addQuadCurve(to: CGPoint(x: centre.x, y: rect.maxY), control: CGPoint(x: centre.x + pinchX, y: centre.y + pinchY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: centre.y), control: CGPoint(x: centre.x - pinchX, y: centre.y + pinchY))
        path.addQuadCurve(to: CGPoint(x: centre.x, y: rect.minY), control: CGPoint(x: centre.x - pinchX, y: centre.y - pinchY))
        path.closeSubpath()
        return path
    }
}

/// The screen behind everything: window grey in Classic, an iridescent pastel wash with
/// sparkles in Y2K Chrome.
struct Win95Backdrop: View {
    var body: some View {
        if Win95.isChrome {
            ChromeBackdrop()
        } else {
            Win95.face
        }
    }
}

/// Behind the tab bar: window grey in Classic, pearl glass in Y2K Chrome.
struct Win95TaskbarBackground: View {
    var body: some View {
        if Win95.isChrome {
            Rectangle().fill(Chrome.panel)
        } else {
            Win95.face
        }
    }
}

private struct ChromeBackdrop: View {
    /// Where each sparkle sits, as fractions of the screen, and how big it is in points.
    private static let sparkles: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (0.07, 0.05, 18), (0.93, 0.09, 12), (0.42, 0.16, 8), (0.16, 0.36, 11),
        (0.88, 0.42, 20), (0.08, 0.68, 14), (0.6, 0.8, 10), (0.94, 0.9, 16),
    ]

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.55, 0.45], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: Chrome.backdropColours
        )
        .overlay {
            LinearGradient(
                colors: [.white.opacity(0), .white.opacity(0.35), .white.opacity(0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .overlay {
            GeometryReader { proxy in
                ForEach(Self.sparkles.indices, id: \.self) { index in
                    let sparkle = Self.sparkles[index]
                    ChromeSparkle()
                        .fill(.white)
                        .frame(width: sparkle.size, height: sparkle.size)
                        .shadow(color: Chrome.glow, radius: 4)
                        .position(x: proxy.size.width * sparkle.x, y: proxy.size.height * sparkle.y)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
