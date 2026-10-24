import Observation
import UIKit

/// Anything that can put a garment on a person photo with AI. `RenderService` is the real one.
protocol TryOnRendering: Sendable {
    func render(person: UIImage, clothing: UIImage, onStatus: @escaping @Sendable (RenderStatus) -> Void) async throws -> URL
}

extension RenderService: TryOnRendering {
    func render(person: UIImage, clothing: UIImage, onStatus: @escaping @Sendable (RenderStatus) -> Void) async throws -> URL {
        try await render(person: person, clothing: clothing, preservePose: true, aspectRatio: .portrait, onStatus: onStatus)
    }
}

/// The AI try-on flow for one garment: camera, countdown, photo, AI render, result.
@MainActor
@Observable
final class AITryOnModel {
    enum Phase: Equatable {
        case camera
        case countdown(Int)
        case rendering(RenderStatus?)
        case result(URL)
        case failed(String)
    }

    let garment: Garment
    let countdownSeconds: Int
    private(set) var phase: Phase
    private(set) var capturedPhoto: UIImage?

    private let productImage: UIImage?
    private let makeRenderer: () throws -> TryOnRendering
    private let sleep: (Duration) async throws -> Void
    private var task: Task<Void, Never>?

    init(
        garment: Garment,
        productImage: UIImage?,
        countdownSeconds: Int = 5,
        makeRenderer: @escaping () throws -> TryOnRendering,
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.garment = garment
        self.productImage = productImage
        self.countdownSeconds = countdownSeconds
        self.makeRenderer = makeRenderer
        self.sleep = sleep
        self.phase = productImage == nil ? .failed(Self.missingPhotoMessage(for: garment)) : .camera
    }

    var canStartCountdown: Bool { phase == .camera }

    /// The shutter: counts down, takes the photo with `capture`, then renders the garment onto it.
    func startCountdown(capture: @escaping @MainActor () async throws -> UIImage) {
        guard canStartCountdown, let productImage else { return }
        phase = .countdown(countdownSeconds)
        task = Task { [weak self] in
            await self?.run(productImage: productImage, capture: capture)
        }
    }

    func retake() {
        task?.cancel()
        task = nil
        capturedPhoto = nil
        phase = productImage == nil ? .failed(Self.missingPhotoMessage(for: garment)) : .camera
    }

    func cancel() {
        task?.cancel()
    }

    func waitUntilFinished() async {
        await task?.value
    }

    /// Progress from the render service. Ignored once the render has finished or been cancelled.
    func applyRenderStatus(_ status: RenderStatus) {
        guard case .rendering = phase else { return }
        phase = .rendering(status)
    }

    static func progressText(for status: RenderStatus?) -> String {
        switch status {
        case .queued(let position?) where position > 0: return "Buffering… \(position) ahead of you"
        case .inProgress: return "Buffering… almost there"
        default: return "Buffering…"
        }
    }

    // MARK: Steps

    private func run(productImage: UIImage, capture: @MainActor () async throws -> UIImage) async {
        let renderer: TryOnRendering
        do {
            renderer = try makeRenderer()
        } catch {
            phase = .failed(Self.message(for: error))
            return
        }
        do {
            try await countDown()
            let photo: UIImage
            do {
                photo = try await capture()
            } catch {
                phase = .failed("Couldn't take the photo. Try again.")
                return
            }
            capturedPhoto = photo
            phase = .rendering(nil)
            let url = try await renderer.render(person: photo, clothing: productImage) { [weak self] status in
                Task { @MainActor in self?.applyRenderStatus(status) }
            }
            try Task.checkCancellation()
            phase = .result(url)
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    private func countDown() async throws {
        for remaining in stride(from: countdownSeconds, through: 1, by: -1) {
            try Task.checkCancellation()
            phase = .countdown(remaining)
            try await sleep(.seconds(1))
        }
    }

    private static func message(for error: Error) -> String {
        if let renderError = error as? RenderError {
            return renderError.localizedDescription
        }
        return "The AI try-on failed. Try again."
    }

    private static func missingPhotoMessage(for garment: Garment) -> String {
        "\(garment.name) doesn't have a product photo yet. Add one called \"\(garment.imageName)\" to the asset catalog."
    }

    #if DEBUG
    func beginRenderingForTesting() {
        phase = .rendering(nil)
    }
    #endif
}
