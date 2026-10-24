import SwiftUI

/// A bright screen border illuminates the face while leaving the camera and controls visible.
struct ScreenRingLight: View {
    var body: some View {
        Rectangle()
            .strokeBorder(.white, lineWidth: 32)
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
