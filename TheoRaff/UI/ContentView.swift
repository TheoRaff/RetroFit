import SwiftUI

/// The try-on screen: the live camera with the current glasses or hat on your face. The deck
/// only holds items the camera can show live; clothes are tried on with AI from the closet.
/// Swipe left or tap Skip for the next item, swipe right to go back, tap Like to save it,
/// tap the shutter to save a photo, turn on the ring light, or flip to rear-camera photography.
struct ContentView: View {
    let session: TryOnSession
    /// Shown by `AppShellView`, so the dialog covers the tab bar too.
    @Binding var tryOnPrompt: AITryOnLook?

    @Environment(\.scenePhase) private var scenePhase
    @State private var snapshotter: ARSnapshotter
    @State private var rearCamera: CameraController
    @State private var camera: TryOnCameraController
    @State private var isVisible = false
    @State private var captureTask: Task<Void, Never>?
    @State private var flipTask: Task<Void, Never>?
    @State private var lightTask: Task<Void, Never>?
    @State private var toastTask: Task<Void, Never>?
    @State private var isCapturing = false
    @State private var showFlash = false
    @State private var toast: String?
    @State private var savedPhotos = 0
    
    @AppStorage("photoCountdownSeconds") private var photoCountdownSeconds = 3

    /// How far a drag has to travel sideways to count as a swipe.
    private let swipeDistance: CGFloat = 60
    private let photoSaver = TryOnPhotoSaver(library: SystemPhotoLibrary())

    init(session: TryOnSession, tryOnPrompt: Binding<AITryOnLook?>) {
        self.session = session
        _tryOnPrompt = tryOnPrompt
        let snapshotter = ARSnapshotter()
        let rearCamera = CameraController()
        _snapshotter = State(initialValue: snapshotter)
        _rearCamera = State(initialValue: rearCamera)
        _camera = State(initialValue: TryOnCameraController(source:
            SystemTryOnCameraSource(snapshotter: snapshotter, rearCamera: rearCamera)))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if camera.mode == .front {
                ARViewContainer(
                    glassesModel: session.currentOutfit?.garment(for: .eyewear)?.modelName,
                    hatModel: session.currentOutfit?.garment(for: .headwear)?.modelName,
                    preloadModels: session.outfits.flatMap(\.garments).compactMap(\.modelName),
                    snapshotter: snapshotter,
                    isActive: camera.showsFrontAR
                )
                .ignoresSafeArea()
            } else {
                CameraPreview(session: rearCamera.session).ignoresSafeArea()
            }

            // The AR view takes touches for itself, so swipes land on this layer above it.
            Color.clear
                .contentShape(Rectangle())
                .gesture(swipeGesture)
                .ignoresSafeArea()

            if camera.isLightOn && camera.mode == .front && camera.isActive {
                ScreenRingLight()
            }

            VStack(spacing: 12) {
                if let toast {
                    Win95Tooltip(text: toast)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                cameraControls
                    .padding(.bottom, 8)
                if camera.mode == .front {
                    outfitControls
                } else {
                    Win95Tooltip(text: "Rear camera · live glasses and hats use the front camera")
                }
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
        .onAppear {
            isVisible = true
            if scenePhase == .active { camera.activate() }
        }
        .onDisappear {
            isVisible = false
            stopCamera()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                stopCamera()
            } else if phase == .active && isVisible {
                camera.activate()
            }
        }
        .onChange(of: camera.error) { _, error in
            if let error { showToast(error) }
        }
    }

    private var cameraControls: some View {
        ShutterButton(isBusy: isCapturing || camera.isBusy, action: capturePhoto)
            .disabled(!camera.isActive || camera.isBusy || isCapturing)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .leading) {
                Button {
                    lightTask = Task { await camera.toggleLight() }
                } label: {
                    Image(systemName: camera.isLightOn ? "lightbulb.fill" : "lightbulb")
                        .font(.system(size: 20)).frame(width: 48, height: 48)
                }
                .buttonStyle(Win95ButtonStyle(isOn: camera.isLightOn))
                .disabled(!camera.isActive || camera.isBusy || isCapturing)
                .accessibilityLabel(camera.isLightOn ? "Turn light off" : "Turn light on")
            }
            .overlay(alignment: .trailing) {
                Button {
                    flipTask = Task { await camera.flip() }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 20)).frame(width: 48, height: 48)
                }
                .buttonStyle(Win95ButtonStyle())
                .disabled(!camera.isActive || camera.isBusy || isCapturing)
                .accessibilityLabel(camera.mode == .front ? "Switch to rear camera" : "Switch to front camera")
            }
    }

    private func stopCamera() {
        captureTask?.cancel()
        flipTask?.cancel()
        lightTask?.cancel()
        toastTask?.cancel()
        showFlash = false
        toast = nil
        camera.deactivate()
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
        guard !isCapturing, camera.isActive, !camera.isBusy else { return }
        isCapturing = true
        captureTask = Task {
            defer { isCapturing = false; captureTask = nil }
            do {
                for remaining in stride(from: max(0, min(photoCountdownSeconds, 10)), through: 1, by: -1) {
                    showToast("Photo in \(remaining)…")
                    try await Task.sleep(for: .seconds(1))
                }
                try Task.checkCancellation()
                let image = try await camera.capture()
                try Task.checkCancellation()
                await flash()
                try Task.checkCancellation()
                let result = await photoSaver.save(image)
                if result == .saved { savedPhotos += 1 }
                if !Task.isCancelled { showToast(result.message) }
            } catch is CancellationError {
                return
            } catch {
                if !Task.isCancelled { showToast(error.localizedDescription) }
            }
        }
    }

    private func flash() async {
        withAnimation(.easeOut(duration: 0.05)) { showFlash = true }
        try? await Task.sleep(for: .milliseconds(120))
        withAnimation(.easeIn(duration: 0.25)) { showFlash = false }
    }

    private func showToast(_ message: String) {
        withAnimation(.snappy) { toast = message }
        toastTask?.cancel()
        toastTask = Task {
            do { try await Task.sleep(for: .seconds(2.5)) } catch { return }
            if toast == message {
                withAnimation(.snappy) { toast = nil }
            }
        }
    }
}

#Preview {
    ContentView(session: TryOnSession(outfits: Catalog.bundled.liveLooks), tryOnPrompt: .constant(nil))
}
