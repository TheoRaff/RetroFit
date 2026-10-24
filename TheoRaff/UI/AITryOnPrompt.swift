import SwiftUI

extension View {
    /// When `garment` is set, asks "Try on … with AI?" and, if the user agrees,
    /// opens the AI try-on camera for that garment.
    func aiTryOnPrompt(for garment: Binding<Garment?>) -> some View {
        modifier(AITryOnPrompt(garment: garment))
    }
}

private struct AITryOnPrompt: ViewModifier {
    @Binding var garment: Garment?
    @State private var tryingOn: Garment?

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Try this on with AI?",
                isPresented: Binding(get: { garment != nil }, set: { if !$0 { garment = nil } }),
                titleVisibility: .visible,
                presenting: garment
            ) { item in
                Button("AI try on") { tryingOn = item }
                Button("Cancel", role: .cancel) {}
            } message: { item in
                Text("Take a photo and see yourself wearing \(item.name).")
            }
            .fullScreenCover(item: $tryingOn) { item in
                AITryOnView(garment: item)
            }
    }
}
