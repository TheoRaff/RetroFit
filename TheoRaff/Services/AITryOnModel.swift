import Observation
import UIKit

/// Anything that can put a garment on a person with AI. `RenderService` is the real one.
protocol TryOnRendering: Sendable {
    func render(person: RenderPerson, clothing: UIImage, onStatus: @escaping @Sendable (RenderStatus) -> Void) async throws -> URL
}

extension RenderService: TryOnRendering {
    func render(person: RenderPerson, clothing: UIImage, onStatus: @escaping @Sendable (RenderStatus) -> Void) async throws -> URL {
        try await render(person: person, clothing: clothing, preservePose: true, aspectRatio: .portrait, onStatus: onStatus)
    }
}

/// The AI try-on flow for a look: camera, countdown, photo, then one AI render per garment,
/// each drawn onto the result of the one before, then the result.
@MainActor
@Observable
final class AITryOnModel {
    enum Phase: Equatable {
        case camera
        /// Seconds left before the photo. 0 while the photo is being taken.
        case countdown(Int)
        case rendering(RenderStatus?)
        case result(URL)
        case failed(String)
    }

    let look: AITryOnLook
    private(set) var phase: Phase
    private(set) var capturedPhoto: UIImage?
    /// Which garment is being rendered, counting from 0.
    private(set) var renderingPiece = 0

    private let productImages: [String: UIImage]
    private let makeRenderer: () throws -> TryOnRendering
    private let sleep: (Duration) async throws -> Void
    private var task: Task<Void, Never>?

    /// `productImages` holds each garment's photo by garment id.
    init(
        look: AITryOnLook,
        productImages: [String: UIImage],
        makeRenderer: @escaping () throws -> TryOnRendering,
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.look = look
        self.productImages = productImages
        self.makeRenderer = makeRenderer
        self.sleep = sleep
        self.phase = .camera
        self.phase = startingPhase
    }

    /// One garment, as from the closet.
    convenience init(
        garment: Garment,
        productImage: UIImage?,
        makeRenderer: @escaping () throws -> TryOnRendering,
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.init(
            look: AITryOnLook(garment: garment),
            productImages: productImage.map { [garment.id: $0] } ?? [:],
            makeRenderer: makeRenderer,
            sleep: sleep
        )
    }

    var canStartCountdown: Bool { phase == .camera }

    /// The shutter: counts down `seconds` (the Profile tab's photo countdown, kept to 0...10),
    /// takes the photo with `capture`, then renders the look onto it.
    func startCountdown(
        seconds: Int,
        capture: @escaping @MainActor () async throws -> UIImage
    ) {
        guard canStartCountdown, let pieces = renderPieces else { return }

        let seconds = PhotoCountdown.clamped(seconds)
        phase = .countdown(seconds)
        task = Task { [weak self] in
            await self?.run(
                pieces: pieces,
                countdownSeconds: seconds,
                capture: capture
            )
        }
    }

    func retake() {
        task?.cancel()
        task = nil
        capturedPhoto = nil
        renderingPiece = 0
        phase = startingPhase
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

    /// The Buffering… text, naming the garment being rendered when there's more than one.
    var progressText: String {
        let status: RenderStatus? = if case .rendering(let status) = phase { status } else { nil }
        let buffering = Self.progressText(for: status)
        guard look.pieceCount > 1, look.garments.indices.contains(renderingPiece) else { return buffering }
        return "\(look.garments[renderingPiece].name) (\(renderingPiece + 1) of \(look.pieceCount))\n\(buffering)"
    }

    static func progressText(for status: RenderStatus?) -> String {
        switch status {
        case .queued(let position?) where position > 0: return "Buffering… \(position) ahead of you"
        case .inProgress: return "Buffering… almost there"
        default: return "Buffering…"
        }
    }

    // MARK: Steps

    /// Each garment with its photo, or nil when one is missing.
    private var renderPieces: [(Garment, UIImage)]? {
        let pieces = look.garments.compactMap { garment in productImages[garment.id].map { (garment, $0) } }
        return pieces.count == look.garments.count && !pieces.isEmpty ? pieces : nil
    }

    private var startingPhase: Phase {
        if let missing = look.garments.first(where: { productImages[$0.id] == nil }) {
            return .failed(Self.missingPhotoMessage(for: missing))
        }
        return .camera
    }

    private func run(
        pieces: [(Garment, UIImage)],
        countdownSeconds: Int,
        capture: @MainActor () async throws -> UIImage
    ) async {
        let renderer: TryOnRendering
        do {
            renderer = try makeRenderer()
        } catch {
            phase = .failed(Self.message(for: error))
            return
        }
        do {
            try await countDown(seconds: countdownSeconds)
            let photo: UIImage
            do {
                photo = try await capture()
            } catch {
                phase = .failed("Couldn't take the photo. Try again.")
                return
            }
            capturedPhoto = photo
            var person = RenderPerson.photo(photo)
            var latest: URL?
            for (index, piece) in pieces.enumerated() {
                renderingPiece = index
                phase = .rendering(nil)
                let url = try await renderer.render(person: person, clothing: piece.1) { [weak self] status in
                    Task { @MainActor in self?.applyRenderStatus(status) }
                }
                try Task.checkCancellation()
                person = .url(url)
                latest = url
            }
            if let latest {
                phase = .result(latest)
            }
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }
    
    private static func message(for error: Error) -> String {
        if let renderError = error as? RenderError {
            return renderError.localizedDescription
        }
        return "The AI try-on failed. Try again."
    }

    private func countDown(seconds: Int) async throws {
        guard seconds > 0 else { return }

        for remaining in stride(from: seconds, through: 1, by: -1) {
            try Task.checkCancellation()
            phase = .countdown(remaining)
            try await sleep(.seconds(1))
        }
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
