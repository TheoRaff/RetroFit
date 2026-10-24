import SwiftUI

extension View {
    /// When `garment` is set, asks "Try this on with AI?" in a Windows message box and,
    /// if the user agrees, opens the AI try-on camera for that garment.
    func aiTryOnPrompt(for garment: Binding<Garment?>) -> some View {
        modifier(AITryOnPrompt(garment: garment))
    }
}

private struct AITryOnPrompt: ViewModifier {
    @Binding var garment: Garment?
    @State private var tryingOn: Garment?

    func body(content: Content) -> some View {
        content
            .win95Modal(item: $garment) { item in
                Win95MessageBox(
                    title: "Try this on with AI?",
                    message: "Take a photo and see yourself wearing \(item.name).",
                    onClose: { garment = nil }
                ) {
                    Win95DialogButton(title: "AI try on", isDefault: true) {
                        garment = nil
                        tryingOn = item
                    }
                    Win95DialogButton(title: "Cancel") { garment = nil }
                }
            }
            .fullScreenCover(item: $tryingOn) { item in
                AITryOnView(garment: item)
            }
    }
}
