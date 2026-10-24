import Observation
import UIKit

@MainActor
protocol TryOnCameraSource {
    func pauseFront()
    func startRear() async throws
    func stopRear()
    func stopRearAndWait() async
    func setTorch(_ enabled: Bool) async throws
    func captureFront() async -> UIImage?
    func captureRear() async throws -> UIImage
}

@MainActor
final class SystemTryOnCameraSource: TryOnCameraSource {
    let snapshotter: ARSnapshotter
    let rearCamera: CameraController

    init(snapshotter: ARSnapshotter, rearCamera: CameraController) {
        self.snapshotter = snapshotter
        self.rearCamera = rearCamera
    }
    func pauseFront() { snapshotter.arView?.session.pause() }
    func startRear() async throws { try await rearCamera.start(position: .back) }
    func stopRear() { rearCamera.stop() }
    func stopRearAndWait() async { await rearCamera.stopAndWait() }
    func setTorch(_ enabled: Bool) async throws { try await rearCamera.setTorch(enabled: enabled) }
    func captureFront() async -> UIImage? { await snapshotter.capture() }
    func captureRear() async throws -> UIImage { try await rearCamera.capturePhoto() }
}

/// Owns the transition between front AR and rear photography, so sessions never run together.
@MainActor
@Observable
final class TryOnCameraController {
    enum Mode { case front, rear }
    private(set) var mode = Mode.front
    private(set) var isActive = false
    private(set) var isSwitching = false
    private(set) var isChangingLight = false
    private(set) var isLightOn = false
    private(set) var error: String?
    private var generation = 0
    private let source: TryOnCameraSource

    var isBusy: Bool { isSwitching || isChangingLight }
    var showsFrontAR: Bool { isActive && mode == .front && !isSwitching }

    init(source: TryOnCameraSource) { self.source = source }

    func activate() { isActive = true }

    func deactivate() {
        generation += 1
        isActive = false
        isSwitching = false
        isChangingLight = false
        isLightOn = false
        mode = .front
        source.pauseFront()
        source.stopRear()
    }

    func flip() async {
        guard isActive, !isBusy else { return }
        let operation = generation
        isSwitching = true
        error = nil
        defer { if operation == generation { isSwitching = false } }
        do {
            if mode == .front {
                source.pauseFront()
                mode = .rear
                try await source.startRear()
                guard operation == generation else { return }
                try Task.checkCancellation()
                if isLightOn { try await source.setTorch(true) }
            } else {
                await source.stopRearAndWait()
                guard operation == generation else { return }
                try Task.checkCancellation()
                mode = .front
            }
        } catch {
            guard operation == generation else { return }
            source.stopRear()
            mode = .front
            isLightOn = false
            if !Task.isCancelled { self.error = error.localizedDescription }
        }
    }

    func toggleLight() async {
        guard isActive, !isBusy else { return }
        let operation = generation
        isChangingLight = true
        error = nil
        defer { if operation == generation { isChangingLight = false } }
        do {
            let enabled = !isLightOn
            if mode == .rear { try await source.setTorch(enabled) }
            guard operation == generation, !Task.isCancelled else { return }
            isLightOn = enabled
        } catch {
            guard operation == generation else { return }
            isLightOn = false
            if !Task.isCancelled { self.error = error.localizedDescription }
        }
    }

    func capture() async throws -> UIImage {
        guard isActive, !isBusy else { throw CameraController.CameraError.unavailable }
        if mode == .rear { return try await source.captureRear() }
        guard let image = await source.captureFront() else { throw CameraController.CameraError.captureFailed }
        return image
    }
}
