import AVFoundation
import UIKit

/// Runs a camera for the AI try-on photo: a live preview plus one still capture.
/// All capture-session work happens on a private queue.
final class CameraController: NSObject, @unchecked Sendable {
    enum CameraError: LocalizedError {
        case notAllowed
        case unavailable
        case captureFailed

        var errorDescription: String? {
            switch self {
            case .notAllowed: return "Allow camera access in Settings to take your try-on photo."
            case .unavailable: return "This device's camera isn't available."
            case .captureFailed: return "Couldn't take the photo. Try again."
            }
        }
    }

    let session = AVCaptureSession()
    private(set) var position: AVCaptureDevice.Position = .front

    private let photoOutput = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "com.theoraff.camera")
    private var input: AVCaptureDeviceInput?
    private var pendingCapture: CheckedContinuation<UIImage, Error>?

    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    func start(position: AVCaptureDevice.Position = .front) async throws {
        guard await Self.requestAccess() else { throw CameraError.notAllowed }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try self.configure(position: position)
                    if !self.session.isRunning {
                        self.session.startRunning()
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func flip() async throws {
        try await start(position: position == .front ? .back : .front)
    }

    func stop() {
        queue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func capturePhoto() async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard self.pendingCapture == nil, self.session.isRunning else {
                    continuation.resume(throwing: CameraError.captureFailed)
                    return
                }
                self.pendingCapture = continuation
                self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            }
        }
    }

    private func configure(position: AVCaptureDevice.Position) throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            throw CameraError.unavailable
        }
        let newInput = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        if let input {
            session.removeInput(input)
        }
        guard session.canAddInput(newInput) else { throw CameraError.unavailable }
        session.addInput(newInput)
        input = newInput
        self.position = position
        if !session.outputs.contains(photoOutput) {
            guard session.canAddOutput(photoOutput) else { throw CameraError.unavailable }
            session.addOutput(photoOutput)
        }
        if let connection = photoOutput.connection(with: .video), connection.isVideoMirroringSupported {
            // Front-camera photos match the mirrored preview people see.
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = position == .front
        }
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        queue.async {
            let continuation = self.pendingCapture
            self.pendingCapture = nil
            if let error {
                continuation?.resume(throwing: error)
            } else if let image {
                continuation?.resume(returning: image)
            } else {
                continuation?.resume(throwing: CameraError.captureFailed)
            }
        }
    }
}
