import SwiftUI

/// The try-on screen: the live camera with the current outfit on your face.
/// Swipe left for the next outfit, right to go back, tap the heart to save it,
/// and tap the shutter to save a photo to your camera roll.
struct ContentView: View {
    let session: TryOnSession

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
                modelName: session.currentOutfit?.garment(for: .eyewear)?.modelName,
                snapshotter: snapshotter
            )
            .ignoresSafeArea()

            // The AR view takes touches for itself, so swipes land on this layer above it.
            Color.clear
                .contentShape(Rectangle())
                .gesture(swipeGesture)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                if let toast {
                    Text(toast)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                ShutterButton(isBusy: isCapturing, action: capturePhoto)
                outfitControls
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)

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
        } else {
            Text("No outfits to try on yet")
                .font(.headline)
                .padding()
                .background(.ultraThinMaterial, in: Capsule())
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
    ContentView(session: TryOnSession(outfits: SampleCatalog.outfits()))
}
