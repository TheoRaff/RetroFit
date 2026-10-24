import SwiftUI

/// The round camera button that saves a photo of what you're trying on.
struct ShutterButton: View {
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(.white, lineWidth: 4)
                    .frame(width: 72, height: 72)
                Circle()
                    .fill(.white.opacity(isBusy ? 0.4 : 0.9))
                    .frame(width: 58, height: 58)
            }
            .shadow(radius: 4)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityLabel("Take photo")
        .accessibilityHint("Saves a photo of what you're trying on to your camera roll")
    }
}
