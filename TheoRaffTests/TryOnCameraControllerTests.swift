import Testing
import UIKit
@testable import TheoRaff

@MainActor
private final class FakeTryOnCameraSource: TryOnCameraSource {
    var events: [String] = []
    var startError: Error?
    var torchError: Error?
    var delayStart = false
    var startContinuation: CheckedContinuation<Void, Never>?
    let frontPhoto = UIImage(systemName: "person")!
    let rearPhoto = UIImage(systemName: "tshirt")!

    func pauseFront() { events.append("pause front") }
    func startRear() async throws {
        events.append("start rear")
        if delayStart {
            await withCheckedContinuation { startContinuation = $0 }
        }
        if let startError { throw startError }
    }
    func stopRear() { events.append("stop rear") }
    func stopRearAndWait() async { events.append("await rear stop") }
    func setTorch(_ enabled: Bool) async throws {
        events.append("torch \(enabled)")
        if let torchError { throw torchError }
    }
    func captureFront() async -> UIImage? { events.append("capture front"); return frontPhoto }
    func captureRear() async throws -> UIImage { events.append("capture rear"); return rearPhoto }
}

@MainActor
struct TryOnCameraControllerTests {
    @Test func flippingStopsOneCameraBeforeStartingTheOther() async {
        let source = FakeTryOnCameraSource()
        let camera = TryOnCameraController(source: source)
        camera.activate()
        #expect(camera.showsFrontAR)
        await camera.flip()
        #expect(camera.mode == .rear)
        #expect(!camera.showsFrontAR)
        await camera.flip()
        #expect(camera.showsFrontAR)
        #expect(source.events == ["pause front", "start rear", "await rear stop"])
    }

    @Test func frontRingLightDoesNotTurnOnTheRearTorch() async {
        let source = FakeTryOnCameraSource()
        let camera = TryOnCameraController(source: source)
        camera.activate()
        await camera.toggleLight()
        #expect(camera.isLightOn)
        #expect(source.events.isEmpty)
        await camera.toggleLight()
        #expect(!camera.isLightOn)
    }

    @Test func enabledLightMovesBetweenRingAndRearTorch() async {
        let source = FakeTryOnCameraSource()
        let camera = TryOnCameraController(source: source)
        camera.activate()
        await camera.toggleLight()
        await camera.flip()
        #expect(source.events.last == "torch true")
        await camera.toggleLight()
        #expect(source.events.last == "torch false")
        #expect(!camera.isLightOn)
    }

    @Test func leavingTryOnStopsCamerasAndResetsTheLight() async {
        let source = FakeTryOnCameraSource()
        let camera = TryOnCameraController(source: source)
        camera.activate()
        await camera.flip()
        await camera.toggleLight()
        camera.deactivate()
        #expect(!camera.isActive)
        #expect(!camera.isLightOn)
        #expect(!camera.showsFrontAR)
        #expect(source.events.suffix(2) == ["pause front", "stop rear"])
    }

    @Test func capturesFromTheSelectedCamera() async throws {
        let source = FakeTryOnCameraSource()
        let camera = TryOnCameraController(source: source)
        camera.activate()
        #expect(try await camera.capture() === source.frontPhoto)
        await camera.flip()
        #expect(try await camera.capture() === source.rearPhoto)
    }

    @Test func failedRearCameraReturnsToFrontWithAnExplanation() async {
        let source = FakeTryOnCameraSource()
        source.startError = CameraController.CameraError.notAllowed
        let camera = TryOnCameraController(source: source)
        camera.activate()
        await camera.flip()
        #expect(camera.showsFrontAR)
        #expect(!camera.isBusy)
        #expect(camera.error == CameraController.CameraError.notAllowed.localizedDescription)
        #expect(source.events.last == "stop rear")
    }

    @Test func unavailableTorchDoesNotLeaveTheLightButtonOn() async {
        let source = FakeTryOnCameraSource()
        source.torchError = CameraController.CameraError.torchUnavailable
        let camera = TryOnCameraController(source: source)
        camera.activate()
        await camera.flip()
        await camera.toggleLight()
        #expect(!camera.isLightOn)
        #expect(camera.error != nil)
        #expect(camera.mode == .rear)
    }

    @Test func lateCameraStartDoesNotReopenAHiddenScreen() async {
        let source = FakeTryOnCameraSource()
        source.delayStart = true
        let camera = TryOnCameraController(source: source)
        camera.activate()
        let switching = Task { await camera.flip() }
        while source.startContinuation == nil { await Task.yield() }
        camera.deactivate()
        source.startContinuation?.resume()
        await switching.value
        #expect(!camera.isActive)
        #expect(!camera.isSwitching)
        #expect(camera.mode == .front)
        #expect(source.events.last == "stop rear")
    }

    @Test func ignoresAnotherFlipWhileTheCameraStarts() async {
        let source = FakeTryOnCameraSource()
        source.delayStart = true
        let camera = TryOnCameraController(source: source)
        camera.activate()
        let switching = Task { await camera.flip() }
        while source.startContinuation == nil { await Task.yield() }
        await camera.flip()
        #expect(source.events.filter { $0 == "start rear" }.count == 1)
        source.startContinuation?.resume()
        await switching.value
        #expect(camera.mode == .rear)
        #expect(!camera.isBusy)
    }
}
