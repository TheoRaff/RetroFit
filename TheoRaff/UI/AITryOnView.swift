import SwiftUI

/// Full-screen AI try-on: live camera, a countdown, then the AI render of you wearing the garment.
struct AITryOnView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: AITryOnModel
    @State private var camera = CameraController()
    @State private var cameraError: String?
    @State private var toast: String?
    @State private var findIt: Garment?

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
            VStack(spacing: 0) {
                // Grey behind the status bar keeps its dark text readable over the camera.
                titleBar
                    .background(alignment: .top) { Win95.face.ignoresSafeArea(edges: .top) }
                Spacer()
                overlay
                    .padding(16)
            }
        }
        .findItPrompt(for: $findIt)
        .preferredColorScheme(.light)
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
                BufferingBar(text: "Downloading your picture…").padding(16)
            }
        case .failed:
            EmptyView()
        }
    }

    /// A window caption with the garment's name, and flip-camera and close buttons on the right.
    private var titleBar: some View {
        Win95TitleBar(title: "AI Try On: \(model.garment.name)", centred: false) {
            HStack(spacing: 2) {
                if model.phase == .camera {
                    captionButton("arrow.triangle.2.circlepath.camera", label: "Flip camera") {
                        Task { await flipCamera() }
                    }
                }
                captionButton("xmark", label: "Close") { dismiss() }
            }
        }
    }

    @ViewBuilder
    private var overlay: some View {
        switch model.phase {
        case .camera:
            VStack(spacing: 12) {
                if let message = cameraError ?? toast {
                    Win95Tooltip(text: message)
                }
                ShutterButton(isBusy: cameraError != nil) {
                    model.startCountdown { try await camera.capturePhoto() }
                }
                .accessibilityLabel("Start \(model.countdownSeconds) second timer")
                Text("Tap to start a \(model.countdownSeconds)-second timer")
                    .font(Win95.font(13, relativeTo: .footnote))
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 0, x: 1, y: 1)
            }
        case .countdown(let seconds):
            Text("\(seconds)")
                .font(Win95.font(120, bold: true, relativeTo: .largeTitle))
                .foregroundStyle(.white)
                .shadow(color: .black, radius: 0, x: 4, y: 4)
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy, value: seconds)
                .frame(maxHeight: .infinity)
        case .rendering(let status):
            BufferingBar(text: AITryOnModel.progressText(for: status))
                .padding(.bottom, 40)
        case .result(let url):
            VStack(spacing: 12) {
                if let toast { Win95Tooltip(text: toast) }
                HStack(spacing: 12) {
                    pillButton("Retake", systemImage: "arrow.counterclockwise") { model.retake() }
                    pillButton("Save to Photos", systemImage: "square.and.arrow.down") {
                        Task { await saveResult(from: url) }
                    }
                }
                HStack(spacing: 12) {
                    pillButton("Find it", systemImage: "bag") { findIt = model.garment }
                    pillButton("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        case .failed(let message):
            Win95MessageBox(
                title: "AI Try On",
                message: message,
                systemImage: "xmark.circle.fill",
                iconColour: .red,
                onClose: { dismiss() }
            ) {
                Win95DialogButton(title: "Try again", isDefault: true) { model.retake() }
                Win95DialogButton(title: "Close") { dismiss() }
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

    /// A small square button for the title bar, like a window's close box.
    private func captionButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 38, height: 32)
        }
        .buttonStyle(Win95ButtonStyle())
        .accessibilityLabel(label)
    }

    private func pillButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            buttonLabel(title, systemImage: systemImage)
        }
        .buttonStyle(Win95ButtonStyle())
    }

    private func buttonLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .labelStyle(Win95ButtonLabelStyle())
            .font(Win95.font(15, bold: true, relativeTo: .headline))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 46)
    }
}
