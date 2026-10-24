import Foundation
import Testing
import UIKit
@testable import TheoRaff

/// Renders instantly with a canned result, reporting the statuses it's given.
private struct FakeRenderer: TryOnRendering {
    var result: Result<URL, RenderError> = .success(URL(string: "https://cdn.example.com/look.png")!)
    var statuses: [RenderStatus] = []

    func render(person: UIImage, clothing: UIImage, onStatus: @escaping @Sendable (RenderStatus) -> Void) async throws -> URL {
        statuses.forEach(onStatus)
        return try result.get()
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
}
