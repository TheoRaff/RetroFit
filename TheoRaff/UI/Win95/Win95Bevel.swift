import SwiftUI
import UIKit

/// The 1-point edge lines that make Windows controls look raised or pressed in.
/// Drawn on top of a view with `.overlay`, so it never changes the layout.
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
        Canvas { context, size in
            let edges = Self.edges(for: style)
            for (inset, topLeft, bottomRight) in edges {
                draw(&context, size: size, inset: inset, topLeft: topLeft, bottomRight: bottomRight)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Outer ring first, then the inner one, as (inset, top-left colour, bottom-right colour).
    private static func edges(for style: Style) -> [(CGFloat, Color, Color)] {
        switch style {
        case .raised:
            [(0, Win95.highlight, Win95.darkShadow), (1, Win95.light, Win95.shadow)]
        case .sunken:
            [(0, Win95.shadow, Win95.highlight), (1, Win95.darkShadow, Win95.light)]
        case .thinSunken:
            [(0, Win95.shadow, Win95.highlight)]
        case .etched:
            [(0, Win95.shadow, Win95.highlight), (1, Win95.highlight, Win95.shadow)]
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

/// The checkerboard Windows draws inside a pressed-in toggle, one point per square.
struct Win95Dither: View {
    var body: some View {
        Image(uiImage: Self.tile)
            .interpolation(.none)
            .resizable(resizingMode: .tile)
            .accessibilityHidden(true)
    }

    private static let tile: UIImage = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2), format: format).image { context in
            UIColor(Win95.ditherDark).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
            UIColor(Win95.ditherLight).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
            context.fill(CGRect(x: 1, y: 1, width: 1, height: 1))
        }
    }()
}

extension View {
    /// A raised grey panel, like a window or a button at rest.
    func win95Raised() -> some View {
        background(Win95.face, ignoresSafeAreaEdges: []).overlay(Win95Bevel(style: .raised))
    }

    /// A sunken well, like a text field, list box or photo frame.
    func win95Sunken(fill: Color = Win95.window) -> some View {
        background(fill, ignoresSafeAreaEdges: []).overlay(Win95Bevel(style: .sunken))
    }
}
