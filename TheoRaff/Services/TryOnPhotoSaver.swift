import Photos
import UIKit

enum PhotoSaveResult: Equatable, Sendable {
    case saved
    case denied
    case failed(String)

    /// What to tell the user after a save attempt.
    var message: String {
        switch self {
        case .saved: return "Saved to Photos"
        case .denied: return "Allow Photos access in Settings to save pictures"
        case .failed(let reason): return "Couldn't save the photo. \(reason)"
        }
    }
}

/// The two photo library calls the saver needs, so tests can swap in a fake.
protocol PhotoLibraryWriting: Sendable {
    func requestAddOnlyAuthorization() async -> PHAuthorizationStatus
    func saveImage(_ image: UIImage) async throws
}

/// The real camera roll. Asks only for permission to add photos, not to read them.
struct SystemPhotoLibrary: PhotoLibraryWriting {
    func requestAddOnlyAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    }

    func saveImage(_ image: UIImage) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
}

/// Saves try-on photos to the user's camera roll.
struct TryOnPhotoSaver: Sendable {
    let library: PhotoLibraryWriting

    func save(_ image: UIImage) async -> PhotoSaveResult {
        switch await library.requestAddOnlyAuthorization() {
        case .authorized, .limited:
            break
        case .denied, .restricted, .notDetermined:
            return .denied
        @unknown default:
            return .denied
        }
        do {
            try await library.saveImage(image)
            return .saved
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
