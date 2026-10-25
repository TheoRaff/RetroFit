import SwiftUI

/// The round camera button that saves a photo of what you're trying on, drawn as a grey
/// Windows button: lit from the top-left, pressed in while you hold it. A glossy pearl disc
/// in Y2K Chrome.
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
        RoundBevelBody(label: configuration.label, pressed: configuration.isPressed, isBusy: isBusy)
    }
}

private struct RoundBevelBody<Label: View>: View {
    let label: Label
    let pressed: Bool
    let isBusy: Bool

    var body: some View {
        let isChrome = Win95.isChrome
        let (outerLit, outerShade, innerLit, innerShade) = pressed
            ? (Win95.darkShadow, Win95.highlight, Win95.shadow, Win95.light)
            : (Win95.highlight, Win95.darkShadow, Win95.light, Win95.shadow)
        label
            .foregroundStyle(isBusy ? Win95.disabledText : Win95.text)
            .win95DisabledEmboss(isBusy)
            .offset(x: pressed && !isChrome ? 1 : 0, y: pressed && !isChrome ? 1 : 0)
            .frame(width: 66, height: 66)
            .background {
                if isChrome {
                    Circle()
                        .fill(pressed ? Chrome.candy : Chrome.pearl)
                        .overlay { Circle().fill(Chrome.sheen).padding(2) }
                        .shadow(color: Chrome.shadowTint, radius: pressed ? 1 : 4, y: pressed ? 0.5 : 2)
                } else {
                    Circle().fill(Win95.face)
                }
            }
            .overlay {
                if isChrome {
                    Circle().strokeBorder(Chrome.rim, lineWidth: 2)
                } else {
                    Circle().strokeBorder(Self.split(lit: outerLit, shade: outerShade), lineWidth: 1.5)
                }
            }
            .overlay {
                if !isChrome {
                    Circle().strokeBorder(Self.split(lit: innerLit, shade: innerShade), lineWidth: 1.5).padding(1.5)
                }
            }
            .overlay {
                // A dark outer ring keeps the button visible over a bright camera picture.
                if isChrome {
                    Circle().strokeBorder(Chrome.ink.opacity(0.55), lineWidth: 1).padding(-1)
                } else {
                    Circle().strokeBorder(Win95.text.opacity(0.8), lineWidth: 1).padding(-1)
                }
            }
            .scaleEffect(pressed && isChrome ? 0.95 : 1)
            .animation(isChrome ? .snappy(duration: 0.12) : nil, value: pressed)
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
