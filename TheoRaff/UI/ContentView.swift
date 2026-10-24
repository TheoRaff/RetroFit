import SwiftUI

/// The try-on screen: the live camera with the current outfit on your face.
/// Swipe left for the next outfit, right to go back, and tap the heart to save it.
struct ContentView: View {
    let session: TryOnSession

    /// How far a drag has to travel sideways to count as a swipe.
    private let swipeDistance: CGFloat = 60

    var body: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer(modelName: session.currentOutfit?.garment(for: .eyewear)?.modelName)
                .ignoresSafeArea()

            // The AR view takes touches for itself, so swipes land on this layer above it.
            Color.clear
                .contentShape(Rectangle())
                .gesture(swipeGesture)
                .ignoresSafeArea()

            if let outfit = session.currentOutfit {
                OutfitCard(
                    outfit: outfit,
                    position: session.currentIndex + 1,
                    total: session.outfits.count,
                    isLiked: session.isCurrentOutfitLiked,
                    canGoBack: session.canShowPrevious,
                    canGoForward: session.canShowNext,
                    onBack: { withAnimation(.snappy) { _ = session.showPrevious() } },
                    onLike: { withAnimation(.snappy) { session.toggleLikeCurrentOutfit() } },
                    onForward: { withAnimation(.snappy) { _ = session.showNext() } }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            } else {
                Text("No outfits to try on yet")
                    .font(.headline)
                    .padding()
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 40)
            }
        }
        .sensoryFeedback(trigger: session.closet.count) { oldCount, newCount in
            newCount > oldCount ? .success : nil
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let sideways = value.translation.width
                guard abs(sideways) > abs(value.translation.height), abs(sideways) > swipeDistance else {
                    return
                }
                withAnimation(.snappy) {
                    _ = sideways < 0 ? session.showNext() : session.showPrevious()
                }
            }
    }
}

#Preview {
    ContentView(session: TryOnSession(outfits: SampleCatalog.outfits()))
}
