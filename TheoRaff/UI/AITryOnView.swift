import SwiftUI

/// Full-screen AI try-on: live camera, a countdown, then the AI render of you wearing the garment.
struct AITryOnView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: AITryOnModel
    @State private var camera = CameraController()
    @State private var cameraError: String?
    @State private var toast: String?

    private let photoSaver = TryOnPhotoSaver(library: SystemPhotoLibrary())

    init(garment: Garment) {
        _model = State(initialValue: AITryOnModel(
            garment: garment,
            productImage: UIImage(named: garment.imageName),
            makeRenderer: { RenderService(config: try RenderConfig.fromBundle()) }
        ))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            background
            VStack {
                topBar
                Spacer()
                overlay
            }
            .padding(16)
        }
        .task { await startCamera() }
        .onDisappear {
            model.cancel()
            camera.stop()
        }
    }

    // MARK: Layers

    @ViewBuilder
    private var background: some View {
        switch model.phase {
        case .camera, .countdown:
            CameraPreview(session: camera.session).ignoresSafeArea()
        case .rendering:
            if let photo = model.capturedPhoto {
                Image(uiImage: photo).resizable().scaledToFill().ignoresSafeArea().opacity(0.5)
            }
        case .result(let url):
            AsyncImage(url: url) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                ProgressView().tint(.white)
            }
        case .failed:
            EmptyView()
        }
    }

    private var topBar: some View {
        HStack {
            roundButton("xmark", label: "Close") { dismiss() }
            Spacer()
            Text(model.garment.name)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            roundButton("arrow.triangle.2.circlepath.camera", label: "Flip camera") {
                Task { await flipCamera() }
            }
            .opacity(model.phase == .camera ? 1 : 0)
            .disabled(model.phase != .camera)
        }
    }

    @ViewBuilder
    private var overlay: some View {
        switch model.phase {
        case .camera:
            VStack(spacing: 12) {
                if let message = cameraError ?? toast {
                    messageText(message)
                }
                ShutterButton(isBusy: cameraError != nil) {
                    model.startCountdown { try await camera.capturePhoto() }
                }
                .accessibilityLabel("Start \(model.countdownSeconds) second timer")
                Text("Tap to start a \(model.countdownSeconds)-second timer")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
            }
        case .countdown(let seconds):
            Text("\(seconds)")
                .font(.system(size: 120, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(radius: 8)
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy, value: seconds)
                .frame(maxHeight: .infinity)
        case .rendering(let status):
            BufferingBar(text: AITryOnModel.progressText(for: status))
                .padding(.bottom, 40)
        case .result(let url):
            VStack(spacing: 12) {
                if let toast { messageText(toast) }
                HStack(spacing: 12) {
                    pillButton("Retake", systemImage: "arrow.counterclockwise") { model.retake() }
                    pillButton("Save to Photos", systemImage: "square.and.arrow.down") {
                        Task { await saveResult(from: url) }
                    }
                }
                HStack(spacing: 12) {
                    FindItMenu(garment: model.garment) {
                        pillLabel("Find it", systemImage: "bag")
                    }
                    pillButton("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        case .failed(let message):
            VStack(spacing: 12) {
                messageText(message)
                HStack(spacing: 12) {
                    pillButton("Try again", systemImage: "arrow.counterclockwise") { model.retake() }
                    pillButton("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    // MARK: Actions

    private func startCamera() async {
        do {
            try await camera.start()
            cameraError = nil
        } catch {
            cameraError = error.localizedDescription
        }
    }

    private func flipCamera() async {
        do {
            try await camera.flip()
        } catch {
            cameraError = error.localizedDescription
        }
    }

    private func saveResult(from url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else {
                toast = PhotoSaveResult.failed("The image couldn't be read.").message
                return
            }
            toast = await photoSaver.save(image).message
        } catch {
            toast = PhotoSaveResult.failed(error.localizedDescription).message
        }
    }

    // MARK: Pieces

    private func roundButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel(label)
    }

    private func pillButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            pillLabel(title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private func pillLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
    }

    private func messageText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
