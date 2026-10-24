import SwiftUI

/// A soft white glow around the screen edge lights the face, like Snapchat's front flash,
/// while the rounded, feathered centre keeps the camera and controls visible.
struct ScreenRingLight: View {
    /// How far the light reaches in from the screen edge.
    private let bandWidth: CGFloat = 30
    /// How gently the light fades into the camera image.
    private let softness: CGFloat = 20
    /// Corner roundness of the clear centre, close to the phone's own corners.
    private let cornerRadius: CGFloat = 60

    var body: some View {
        Color.white
            .mask {
                Rectangle()
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .padding(bandWidth)
                            .blur(radius: softness)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
            }
            .background(BrightnessBoost().frame(width: 0, height: 0))
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct BrightnessBoost: UIViewRepresentable {
    func makeUIView(context: Context) -> BrightnessView { BrightnessView() }
    func updateUIView(_ uiView: BrightnessView, context: Context) {}
    static func dismantleUIView(_ uiView: BrightnessView, coordinator: ()) { uiView.restore() }

    final class BrightnessView: UIView {
        private weak var litScreen: UIScreen?
        private var previousBrightness: CGFloat?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            restore()
            guard let screen = window?.windowScene?.screen else { return }
            previousBrightness = screen.brightness
            litScreen = screen
            screen.brightness = 1
        }

        func restore() {
            if let previousBrightness { litScreen?.brightness = previousBrightness }
            previousBrightness = nil
            litScreen = nil
        }
    }
}
