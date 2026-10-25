import SwiftUI
import UIKit

/// The 1-point edge lines that make Windows controls look raised or pressed in.
/// Drawn on top of a view with `.overlay`, so it never changes the layout.
/// In Y2K Chrome it's a polished rounded rim instead.
struct Win95Bevel: View {
    enum Style {
        /// Buttons and panels: light top-left, dark bottom-right.
        case raised
        /// Pressed buttons, text fields, list boxes and photo wells.
        case sunken
        /// A single-line sunken frame, for small read-outs such as "3 of 6".
        case thinSunken
        /// The grooved line around a group box: a shadow line with a highlight line inside it.
        case etched
    }

    let style: Style

    var body: some View {
        Group {
            if Win95.isChrome {
                ChromeRim(style: style)
            } else {
                let edges = Self.edges(for: style, palette: Win95.palette)
                Canvas { context, size in
                    for (inset, topLeft, bottomRight) in edges {
                        draw(&context, size: size, inset: inset, topLeft: topLeft, bottomRight: bottomRight)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Outer ring first, then the inner one, as (inset, top-left colour, bottom-right colour).
    private static func edges(for style: Style, palette: Win95Palette) -> [(CGFloat, Color, Color)] {
        switch style {
        case .raised:
            [(0, palette.highlight, palette.darkShadow), (1, palette.light, palette.shadow)]
        case .sunken:
            [(0, palette.shadow, palette.highlight), (1, palette.darkShadow, palette.light)]
        case .thinSunken:
            [(0, palette.shadow, palette.highlight)]
        case .etched:
            [(0, palette.shadow, palette.highlight), (1, palette.highlight, palette.shadow)]
        }
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize, inset: CGFloat, topLeft: Color, bottomRight: Color) {
        let width = size.width - inset * 2
        let height = size.height - inset * 2
        guard width > 1, height > 1 else { return }
        context.fill(Path(CGRect(x: inset, y: inset, width: width, height: 1)), with: .color(topLeft))
        context.fill(Path(CGRect(x: inset, y: inset, width: 1, height: height)), with: .color(topLeft))
        // Bottom-right goes on top, so it owns the two far corners, as on Windows.
        context.fill(Path(CGRect(x: inset, y: inset + height - 1, width: width, height: 1)), with: .color(bottomRight))
        context.fill(Path(CGRect(x: inset + width - 1, y: inset, width: 1, height: height)), with: .color(bottomRight))
    }
}

/// The Y2K Chrome edge for each bevel style.
private struct ChromeRim: View {
    let style: Win95Bevel.Style

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Chrome.cornerRadius, style: .continuous)
        switch style {
        case .raised:
            shape.strokeBorder(Chrome.rim, lineWidth: 1.5)
        case .sunken:
            shape.strokeBorder(Chrome.wellRim, lineWidth: 1.5)
        case .thinSunken:
            shape.strokeBorder(Win95Palette.chrome.shadow, lineWidth: 1)
        case .etched:
            ZStack {
                shape.strokeBorder(.white.opacity(0.9), lineWidth: 2)
                shape.strokeBorder(Win95Palette.chrome.shadow.opacity(0.7), lineWidth: 0.75)
            }
        }
    }
}

/// The checkerboard Windows draws inside a pressed-in toggle, one point per square.
/// Candy pink glass in Y2K Chrome.
struct Win95Dither: View {
    var body: some View {
        if Win95.isChrome {
            RoundedRectangle(cornerRadius: Chrome.cornerRadius, style: .continuous)
                .fill(Chrome.candy)
                .accessibilityHidden(true)
        } else {
            Image(uiImage: Self.tile)
                .interpolation(.none)
                .resizable(resizingMode: .tile)
                .accessibilityHidden(true)
        }
    }

    /// Always in the Classic colours, whichever theme is showing when it's first drawn.
    private static let tile: UIImage = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2), format: format).image { context in
            UIColor(Win95Palette.classic.ditherDark).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
            UIColor(Win95Palette.classic.ditherLight).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
            context.fill(CGRect(x: 1, y: 1, width: 1, height: 1))
        }
    }()
}

extension View {
    /// A raised grey panel, like a window or a button at rest. Floating glass in Y2K Chrome.
    func win95Raised() -> some View {
        Win95Panel(content: self, style: .raised, fill: Win95.face)
    }

    /// A sunken well, like a text field, list box or photo frame. Clear glass in Y2K Chrome,
    /// where its content is clipped to the rounded corners unless `clipsContent` is false.
    func win95Sunken(fill: Color = Win95.window, clipsContent: Bool = true) -> some View {
        Win95Panel(content: self, style: .sunken, fill: fill, clipsContent: clipsContent)
    }
}

private struct Win95Panel<Content: View>: View {
    let content: Content
    let style: Win95Bevel.Style
    let fill: Color
    var clipsContent = true

    var body: some View {
        // One modifier chain for both themes, so switching theme keeps `content` (and any
        // scroll position or text field inside it) instead of building it again.
        content
            .clipShape(Win95PanelClip(cornerRadius: Win95.isChrome && clipsContent ? Chrome.cornerRadius : nil))
            .background { Win95PanelFill(style: style, fill: fill) }
            .overlay(Win95Bevel(style: style))
    }
}

/// Rounds off what's inside a Y2K Chrome panel. With no corner radius it clips nothing, as
/// Classic panels never did, so text selection handles can still hang outside a field.
private struct Win95PanelClip: Shape {
    let cornerRadius: CGFloat?

    func path(in rect: CGRect) -> Path {
        guard let cornerRadius else {
            return Path(rect.insetBy(dx: -10_000, dy: -10_000))
        }
        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: rect)
    }
}

/// Behind a panel: its fill, or pearl glass with a soft shadow for raised Y2K Chrome panels.
private struct Win95PanelFill: View {
    let style: Win95Bevel.Style
    let fill: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Win95.cornerRadius, style: .continuous)
        if Win95.isChrome && style == .raised {
            shape.fill(Chrome.panel).shadow(color: Chrome.shadowTint, radius: 8, y: 3)
        } else {
            shape.fill(fill)
        }
    }
}
