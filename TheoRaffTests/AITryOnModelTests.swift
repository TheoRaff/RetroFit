import Foundation
import Testing
import UIKit
@testable import TheoRaff

/// Renders instantly with a canned result, reporting the statuses it's given.
private struct FakeRenderer: TryOnRendering {
    var result: Result<URL, RenderError> = .success(URL(string: "https://cdn.example.com/look.png")!)
    var statuses: [RenderStatus] = []

    func render(person: RenderPerson, clothing: UIImage, onStatus: @escaping @Sendable (RenderStatus) -> Void) async throws -> URL {
        statuses.forEach(onStatus)
        return try result.get()
    }
}

/// Returns step-1.png, step-2.png… and records what each render was given.
private final class ChainRenderer: TryOnRendering, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var people: [RenderPerson] = []
    private(set) var clothes: [UIImage] = []

    func render(person: RenderPerson, clothing: UIImage, onStatus: @escaping @Sendable (RenderStatus) -> Void) async throws -> URL {
        lock.lock()
        defer { lock.unlock() }
        people.append(person)
        clothes.append(clothing)
        return URL(string: "https://cdn.example.com/step-\(people.count).png")!
    }
}

private struct CameraBroke: Error {}

@MainActor
private final class PhaseRecorder {
    private(set) var phases: [AITryOnModel.Phase] = []
    func record(_ phase: AITryOnModel.Phase) { phases.append(phase) }
}

@MainActor
struct AITryOnModelTests {
    private let hoodie = try! Fixtures.garment(id: "pink-velour-hoodie")
    private let product = UIImage(systemName: "tshirt")!
    private let selfie = UIImage(systemName: "person")!

    private func makeModel(
        productImage: UIImage?,
        countdown: Int = 3,
        renderer: @escaping () throws -> TryOnRendering = { FakeRenderer() },
        recorder: PhaseRecorder? = nil
    ) -> AITryOnModel {
        var model: AITryOnModel!
        model = AITryOnModel(
            garment: hoodie,
            productImage: productImage,
            countdownSeconds: countdown,
            makeRenderer: renderer,
            sleep: { _ in await MainActor.run { recorder?.record(model.phase) } }
        )
        return model
    }

    @Test func opensOnTheCameraWhenThereIsAProductPhoto() {
        let model = makeModel(productImage: product)
        #expect(model.phase == .camera)
        #expect(model.canStartCountdown)
    }

    @Test func explainsAMissingProductPhotoStraightAway() {
        let model = makeModel(productImage: nil)
        guard case .failed(let message) = model.phase else {
            Issue.record("Expected a failure, got \(model.phase)")
            return
        }
        #expect(message.contains("Garment pink-velour-hoodie"))
        #expect(message.contains("pink-velour-hoodie-photo"))
        #expect(model.canStartCountdown == false)
    }

    @Test func countsDownThenRendersTheCapturedPhoto() async {
        let recorder = PhaseRecorder()
        let model = makeModel(productImage: product, countdown: 3, recorder: recorder)
        model.startCountdown { self.selfie }
        await model.waitUntilFinished()

        #expect(recorder.phases == [.countdown(3), .countdown(2), .countdown(1)])
        #expect(model.phase == .result(URL(string: "https://cdn.example.com/look.png")!))
        #expect(model.capturedPhoto === selfie)
    }

    @Test func rendersALibraryPhotoWithoutCountingDown() async {
        let recorder = PhaseRecorder()
        let renderer = ChainRenderer()
        let model = makeModel(productImage: product, renderer: { renderer }, recorder: recorder)
        model.start(photo: selfie)
        #expect(model.phase == .rendering(nil))
        #expect(model.canStartCountdown == false)
        await model.waitUntilFinished()

        #expect(recorder.phases.isEmpty)
        #expect(model.capturedPhoto === selfie)
        #expect(model.phase == .result(URL(string: "https://cdn.example.com/step-1.png")!))
        guard case .photo(let person)? = renderer.people.first else {
            Issue.record("Expected the selected photo to be sent to the renderer")
            return
        }
        #expect(person === selfie)
        #expect(renderer.clothes.first === product)
    }

    @Test func ignoresAnotherPhotoOrShutterWhileRendering() async {
        let renderer = ChainRenderer()
        let model = makeModel(productImage: product, renderer: { renderer })
        model.start(photo: selfie)
        model.start(photo: product)
        var captures = 0
        model.startCountdown { captures += 1; return self.selfie }
        await model.waitUntilFinished()

        #expect(captures == 0)
        #expect(renderer.people.count == 1)
        #expect(model.capturedPhoto === selfie)
    }

    @Test func cannotRenderALibraryPhotoWithoutTheProductPhoto() async {
        let renderer = ChainRenderer()
        let model = makeModel(productImage: nil, renderer: { renderer })
        model.start(photo: selfie)
        await model.waitUntilFinished()

        guard case .failed = model.phase else {
            Issue.record("Expected the missing-product-photo failure")
            return
        }
        #expect(renderer.people.isEmpty)
        #expect(model.capturedPhoto == nil)
    }

    @Test func libraryPhotoUsesTheRenderErrorScreen() async {
        let model = makeModel(productImage: product, renderer: { FakeRenderer(result: .failure(.timedOut)) })
        model.start(photo: selfie)
        await model.waitUntilFinished()
        #expect(model.phase == .failed("The render is taking too long. Try again."))
        model.retake()
        #expect(model.phase == .camera)
        #expect(model.capturedPhoto == nil)
    }

    @Test func canRenderTheSameLibraryPhotoAfterRetaking() async {
        let renderer = ChainRenderer()
        let model = makeModel(productImage: product, renderer: { renderer })
        model.start(photo: selfie)
        await model.waitUntilFinished()
        model.retake()
        model.start(photo: selfie)
        await model.waitUntilFinished()

        #expect(renderer.people.count == 2)
        #expect(model.capturedPhoto === selfie)
        #expect(model.phase == .result(URL(string: "https://cdn.example.com/step-2.png")!))
    }

    @Test func cancellingBeforeALibraryRenderStartsMakesNoRequest() async {
        let renderer = ChainRenderer()
        let model = makeModel(productImage: product, renderer: { renderer })
        model.start(photo: selfie)
        model.cancel()
        await model.waitUntilFinished()
        #expect(renderer.people.isEmpty)
    }

    @Test func ignoresTheShutterOnceStarted() async {
        let model = makeModel(productImage: product)
        var captures = 0
        model.startCountdown { captures += 1; return self.selfie }
        model.startCountdown { captures += 1; return self.selfie }
        await model.waitUntilFinished()
        #expect(captures == 1)
    }

    @Test func reportsACameraFailure() async {
        let model = makeModel(productImage: product)
        model.startCountdown { throw CameraBroke() }
        await model.waitUntilFinished()
        #expect(model.phase == .failed("Couldn't take the photo. Try again."))
    }

    @Test func stopsBeforeTheCountdownWhenRenderingIsNotSetUp() async {
        let recorder = PhaseRecorder()
        let model = makeModel(
            productImage: product,
            renderer: { throw RenderError.missingConfig("RenderAPIToken") },
            recorder: recorder
        )
        var captured = false
        model.startCountdown { captured = true; return self.selfie }
        await model.waitUntilFinished()
        #expect(recorder.phases.isEmpty)
        #expect(captured == false)
        #expect(model.phase == .failed(RenderError.missingConfig("RenderAPIToken").localizedDescription))
    }

    @Test func showsTheRenderErrorMessage() async {
        let model = makeModel(productImage: product, renderer: { FakeRenderer(result: .failure(.timedOut)) })
        model.startCountdown { self.selfie }
        await model.waitUntilFinished()
        #expect(model.phase == .failed("The render is taking too long. Try again."))
    }

    @Test func retakeGoesBackToTheCamera() async {
        let model = makeModel(productImage: product)
        model.startCountdown { self.selfie }
        await model.waitUntilFinished()
        model.retake()
        #expect(model.phase == .camera)
        #expect(model.capturedPhoto == nil)
    }

    @Test func showsRenderProgressOnlyWhileRendering() {
        let model = makeModel(productImage: product)
        model.applyRenderStatus(.queued(position: 2))
        #expect(model.phase == .camera)

        model.beginRenderingForTesting()
        model.applyRenderStatus(.queued(position: 2))
        #expect(model.phase == .rendering(.queued(position: 2)))
        model.applyRenderStatus(.inProgress)
        #expect(model.phase == .rendering(.inProgress))
    }

    @Test(arguments: [
        (RenderStatus?.none, "Buffering…"),
        (.queued(position: 3), "Buffering… 3 ahead of you"),
        (.queued(position: nil), "Buffering…"),
        (.inProgress, "Buffering… almost there"),
    ])
    func describesProgress(status: RenderStatus?, text: String) {
        #expect(AITryOnModel.progressText(for: status) == text)
    }

    // MARK: Whole outfits

    @Test(arguments: [false, true])
    func rendersEachPieceOntoTheLastResult(fromLibrary: Bool) async throws {
        let jersey = try Fixtures.garment(id: "jersey", category: .top)
        let jeans = try Fixtures.garment(id: "jeans", category: .bottom)
        let jerseyPhoto = UIImage(systemName: "tshirt")!
        let jeansPhoto = UIImage(systemName: "figure.walk")!
        let renderer = ChainRenderer()
        let model = AITryOnModel(
            look: AITryOnLook(title: "Court Kings", garments: [jeans, jersey]),
            productImages: [jersey.id: jerseyPhoto, jeans.id: jeansPhoto],
            countdownSeconds: 1,
            makeRenderer: { renderer },
            sleep: { _ in }
        )
        if fromLibrary {
            model.start(photo: selfie)
        } else {
            model.startCountdown { self.selfie }
        }
        await model.waitUntilFinished()

        #expect(model.phase == .result(URL(string: "https://cdn.example.com/step-2.png")!))
        #expect(renderer.clothes.count == 2)
        #expect(renderer.clothes.first === jerseyPhoto)
        #expect(renderer.clothes.last === jeansPhoto)
        guard case .photo(let first)? = renderer.people.first, case .url(let second)? = renderer.people.last else {
            Issue.record("Expected the photo, then the first result, got \(renderer.people)")
            return
        }
        #expect(first === selfie)
        #expect(second == URL(string: "https://cdn.example.com/step-1.png")!)
    }

    @Test func saysWhichPieceIsRendering() throws {
        let jersey = try Fixtures.garment(id: "jersey", category: .top)
        let jeans = try Fixtures.garment(id: "jeans", category: .bottom)
        let model = AITryOnModel(
            look: AITryOnLook(title: "Court Kings", garments: [jersey, jeans]),
            productImages: [jersey.id: product, jeans.id: product],
            makeRenderer: { FakeRenderer() }
        )
        model.beginRenderingForTesting()
        #expect(model.progressText == "Garment jersey (1 of 2)\nBuffering…")
        #expect(makeModel(productImage: product).progressText == "Buffering…")
    }

    @Test func explainsAMissingPhotoForAnyPieceStraightAway() throws {
        let jersey = try Fixtures.garment(id: "jersey", category: .top)
        let jeans = try Fixtures.garment(id: "jeans", category: .bottom)
        let model = AITryOnModel(
            look: AITryOnLook(title: "Court Kings", garments: [jersey, jeans]),
            productImages: [jersey.id: product],
            makeRenderer: { FakeRenderer() }
        )
        guard case .failed(let message) = model.phase else {
            Issue.record("Expected a failure, got \(model.phase)")
            return
        }
        #expect(message.contains("Garment jeans"))
        #expect(model.canStartCountdown == false)
    }
}
