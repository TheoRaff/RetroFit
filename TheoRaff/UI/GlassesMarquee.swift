import Observation
import SwiftUI

/// Where the 3D glasses are on screen, fed by `ARViewContainer` as the face moves.
/// Only `GlassesMarquee` reads it, so the rest of the try-on screen doesn't redraw every frame.
@Observable
final class GlassesTracker {
    var frame: CGRect?
}

/// A dotted Windows selection box with square corner handles around the glasses, as in the
/// mockup. Draws in the AR view's coordinates, so place it over the AR view, ignoring safe areas.
struct GlassesMarquee: View {
    let tracker: GlassesTracker

    /// Space between the glasses and the box.
    private let margin: CGFloat = 6
    private let handle: CGFloat = 6

    var body: some View {
        Canvas { context, _ in
            guard let raw = tracker.frame else { return }
            // Snap to whole points so the 1-point dots stay crisp.
            let frame = raw.insetBy(dx: -margin, dy: -margin).integral.insetBy(dx: 0.5, dy: 0.5)
            let box = Path(frame)
            context.stroke(box, with: .color(.black.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [2, 2], dashPhase: 2))
            context.stroke(box, with: .color(.white), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            for corner in [CGPoint(x: frame.minX, y: frame.minY), CGPoint(x: frame.maxX, y: frame.minY),
                           CGPoint(x: frame.minX, y: frame.maxY), CGPoint(x: frame.maxX, y: frame.maxY)] {
                let square = CGRect(x: corner.x - handle / 2, y: corner.y - handle / 2, width: handle, height: handle)
                context.fill(Path(square), with: .color(.white))
                context.stroke(Path(square), with: .color(Win95.darkShadow), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
