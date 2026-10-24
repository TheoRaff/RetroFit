import SwiftUI

/// The round camera button that saves a photo of what you're trying on, drawn as a grey
/// Windows button: lit from the top-left, pressed in while you hold it.
struct ShutterButton: View {
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "camera.fill")
                .font(.system(size: 24, weight: .semibold))
        }
        .buttonStyle(RoundBevelStyle(isBusy: isBusy))
        .disabled(isBusy)
        .accessibilityLabel("Take photo")
        .accessibilityHint("Saves a photo of what you're trying on to your camera roll")
    }
}

/// The Windows bevel bent into a circle: two 1-point rings, each split hard along the
/// top-right to bottom-left diagonal into a lit half and a shadowed half.
private struct RoundBevelStyle: ButtonStyle {
    let isBusy: Bool

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let (outerLit, outerShade, innerLit, innerShade) = pressed
            ? (Win95.darkShadow, Win95.highlight, Win95.shadow, Win95.light)
            : (Win95.highlight, Win95.darkShadow, Win95.light, Win95.shadow)
        configuration.label
            .foregroundStyle(isBusy ? Win95.disabledText : Win95.text)
            .win95DisabledEmboss(isBusy)
            .offset(x: pressed ? 1 : 0, y: pressed ? 1 : 0)
            .frame(width: 66, height: 66)
            .background(Circle().fill(Win95.face))
            .overlay(Circle().strokeBorder(Self.split(lit: outerLit, shade: outerShade), lineWidth: 1.5))
            .overlay(Circle().strokeBorder(Self.split(lit: innerLit, shade: innerShade), lineWidth: 1.5).padding(1.5))
            .overlay(Circle().strokeBorder(Win95.text.opacity(0.8), lineWidth: 1).padding(-1))
            .contentShape(Circle())
    }

    /// Angles run clockwise from 3 o'clock: 0.375 is the bottom-left, 0.875 the top-right.
    private static func split(lit: Color, shade: Color) -> AngularGradient {
        AngularGradient(stops: [
            .init(color: shade, location: 0),
            .init(color: shade, location: 0.375),
            .init(color: lit, location: 0.375),
            .init(color: lit, location: 0.875),
            .init(color: shade, location: 0.875),
            .init(color: shade, location: 1),
        ], center: .center)
    }
}
