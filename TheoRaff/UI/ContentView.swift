import SwiftUI

/// The try-on screen: the live camera with the current outfit on your face.
/// Swipe left or tap Skip for the next outfit, swipe right to go back, tap Like to save it,
/// tap the shutter to save a photo to your camera roll, and tap AI to try the whole look on with AI.
struct ContentView: View {
    let session: TryOnSession
    /// Shown by `AppShellView`, so the dialog covers the tab bar too.
    @Binding var tryOnPrompt: AITryOnLook?

    @State private var snapshotter = ARSnapshotter()
    @State private var isCapturing = false
    @State private var showFlash = false
    @State private var toast: String?
    @State private var savedPhotos = 0

    /// How far a drag has to travel sideways to count as a swipe.
    private let swipeDistance: CGFloat = 60
    private let photoSaver = TryOnPhotoSaver(library: SystemPhotoLibrary())

    var body: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer(
                glassesModel: session.currentOutfit?.garment(for: .eyewear)?.modelName,
                hatModel: session.currentOutfit?.garment(for: .headwear)?.modelName,
                preloadModels: session.outfits.flatMap(\.garments).compactMap(\.modelName),
                snapshotter: snapshotter
            )
            .ignoresSafeArea()

            // The AR view takes touches for itself, so swipes land on this layer above it.
            Color.clear
                .contentShape(Rectangle())
                .gesture(swipeGesture)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                if let toast {
                    Win95Tooltip(text: toast)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                ShutterButton(isBusy: isCapturing, action: capturePhoto)
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .trailing) { aiButton }
                    .padding(.bottom, 8)
                outfitControls
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 13)

            if showFlash {
                Color.white
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .sensoryFeedback(trigger: session.closet.count) { oldCount, newCount in
            newCount > oldCount ? .success : nil
        }
        .sensoryFeedback(.success, trigger: savedPhotos)
    }

    @ViewBuilder
    private var outfitControls: some View {
        if let outfit = session.currentOutfit {
            VStack(spacing: 12) {
                OutfitCard(
                    outfit: outfit,
                    position: session.currentIndex + 1,
                    total: session.outfits.count,
                    canGoBack: session.canShowPrevious,
                    canGoForward: session.canShowNext,
                    onBack: { withAnimation(.snappy) { _ = session.showPrevious() } },
                    onForward: { withAnimation(.snappy) { _ = session.showNext() } }
                )
                .contentShape(Rectangle())
                .gesture(swipeGesture)
                deckButtons
            }
        } else {
            Win95Tooltip(text: "No outfits to try on yet")
        }
    }

    /// Tries the whole current look on with AI, every piece of clothing in it.
    @ViewBuilder
    private var aiButton: some View {
        if let outfit = session.currentOutfit {
            Button {
                tryOnPrompt = AITryOnLook(outfit: outfit)
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 18, weight: .semibold))
                    Text("AI")
                        .font(Win95.font(12, bold: true))
                }
                .frame(width: 58, height: 52)
            }
            .buttonStyle(Win95ButtonStyle())
            .accessibilityLabel("Try this look on with AI")
        }
    }

    /// Skip and Like, the two big buttons under the card. On the last look, Skip becomes
    /// Start over, so the deck never looks stuck.
    private var deckButtons: some View {
        let isLiked = session.isCurrentOutfitLiked
        let atEnd = !session.canShowNext
        return HStack(spacing: 12) {
            Button {
                withAnimation(.snappy) {
                    if atEnd, let first = session.outfits.first {
                        session.show(outfitID: first.id)
                    } else {
                        session.showNext()
                    }
                }
            } label: {
                Label(atEnd ? "Start over" : "Skip", systemImage: atEnd ? "arrow.counterclockwise" : "xmark")
                    .font(Win95.font(17, relativeTo: .headline))
                    .labelStyle(Win95ButtonLabelStyle())
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(Win95ButtonStyle())
            .accessibilityLabel(atEnd ? "Start the deck again" : "Skip this look")

            Button {
                withAnimation(.snappy) { session.toggleLikeCurrentOutfit() }
            } label: {
                HStack(spacing: 8) {
                    Win95Heart()
                    Text(isLiked ? "Liked" : "Like")
                        .font(Win95.font(17, bold: true, relativeTo: .headline))
                }
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(Win95ButtonStyle(isOn: isLiked))
            .accessibilityLabel(isLiked ? "Remove this look from your closet" : "Save this look to your closet")
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

    // MARK: Photos

    private func capturePhoto() {
        guard !isCapturing else { return }
        isCapturing = true
        Task {
            defer { isCapturing = false }
            guard let image = await snapshotter.capture() else {
                showToast("Couldn't take the photo. Try again.")
                return
            }
            await flash()
            let result = await photoSaver.save(image)
            if result == .saved {
                savedPhotos += 1
            }
            showToast(result.message)
        }
    }

    private func flash() async {
        withAnimation(.easeOut(duration: 0.05)) { showFlash = true }
        try? await Task.sleep(for: .milliseconds(120))
        withAnimation(.easeIn(duration: 0.25)) { showFlash = false }
    }

    private func showToast(_ message: String) {
        withAnimation(.snappy) { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if toast == message {
                withAnimation(.snappy) { toast = nil }
            }
        }
    }
}

#Preview {
    ContentView(session: TryOnSession(outfits: Catalog.bundled.outfits), tryOnPrompt: .constant(nil))
}
