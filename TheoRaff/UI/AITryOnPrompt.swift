import SwiftUI

extension View {
    /// When `look` is set, asks "Try this on with AI?" in a Windows message box and, if the
    /// user agrees, opens the AI try-on camera for it. For a single piece of clothing it also
    /// offers to add it to the session's fitting room, to try on with other pieces.
    func aiTryOnPrompt(for look: Binding<AITryOnLook?>, session: TryOnSession) -> some View {
        modifier(AITryOnPrompt(look: look, session: session))
    }
}

private struct AITryOnPrompt: ViewModifier {
    @Binding var look: AITryOnLook?
    let session: TryOnSession
    @State private var tryingOn: AITryOnLook?

    func body(content: Content) -> some View {
        content
            .win95Modal(item: $look) { item in
                Win95MessageBox(
                    title: "Try this on with AI?",
                    message: message(for: item),
                    onClose: { look = nil }
                ) {
                    Win95DialogButton(title: "AI try on", isDefault: true) {
                        look = nil
                        tryingOn = item
                    }
                    if let piece = addablePiece(of: item) {
                        Win95DialogButton(title: session.isInFittingRoom(piece) ? "In outfit" : "Add to outfit") {
                            session.addToFittingRoom(piece)
                            look = nil
                        }
                        .disabled(session.isInFittingRoom(piece))
                    }
                    Win95DialogButton(title: "Cancel") { look = nil }
                }
            }
            .fullScreenCover(item: $tryingOn) { item in
                AITryOnView(look: item)
            }
    }

    private func message(for look: AITryOnLook) -> String {
        guard look.pieceCount > 1 else {
            return "Take a photo and see yourself wearing \(look.title)."
        }
        let names = look.garments.map(\.name).joined(separator: " and ")
        return "Take a photo and see yourself wearing the \(names). That's \(look.pieceCount) renders, one after the other, so it takes a little longer."
    }

    /// The garment to offer "Add to outfit" for: a single piece of clothing, not shades or a hat.
    private func addablePiece(of look: AITryOnLook) -> Garment? {
        guard look.pieceCount == 1, let garment = look.garments.first,
              garment.category.liveStyle != .faceModel else { return nil }
        return garment
    }
}
