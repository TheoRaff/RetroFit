import Photos
import Testing
import UIKit
@testable import TheoRaff

/// A stand-in for the photo library, so tests never touch the real camera roll.
private final class FakePhotoLibrary: PhotoLibraryWriting, @unchecked Sendable {
    let status: PHAuthorizationStatus
    let saveError: Error?
    private(set) var savedCount = 0

    init(status: PHAuthorizationStatus, saveError: Error? = nil) {
        self.status = status
        self.saveError = saveError
    }

    func requestAddOnlyAuthorization() async -> PHAuthorizationStatus { status }

    func saveImage(_ image: UIImage) async throws {
        if let saveError { throw saveError }
        savedCount += 1
    }
}

private struct DiskFull: LocalizedError {
    var errorDescription: String? { "The disk is full." }
}

struct TryOnPhotoSaverTests {
    private let photo = UIImage()

    @Test(arguments: [PHAuthorizationStatus.authorized, .limited])
    func savesWhenAllowed(status: PHAuthorizationStatus) async {
        let library = FakePhotoLibrary(status: status)
        let result = await TryOnPhotoSaver(library: library).save(photo)
        #expect(result == .saved)
        #expect(library.savedCount == 1)
    }

    @Test(arguments: [PHAuthorizationStatus.denied, .restricted, .notDetermined])
    func doesNotSaveWithoutPermission(status: PHAuthorizationStatus) async {
        let library = FakePhotoLibrary(status: status)
        let result = await TryOnPhotoSaver(library: library).save(photo)
        #expect(result == .denied)
        #expect(library.savedCount == 0)
    }

    @Test func reportsASaveFailure() async {
        let library = FakePhotoLibrary(status: .authorized, saveError: DiskFull())
        let result = await TryOnPhotoSaver(library: library).save(photo)
        #expect(result == .failed("The disk is full."))
    }

    @Test(arguments: [
        (PhotoSaveResult.saved, "Saved to Photos"),
        (.denied, "Allow Photos access in Settings to save pictures"),
        (.failed("The disk is full."), "Couldn't save the photo. The disk is full."),
    ])
    func explainsEachResult(result: PhotoSaveResult, message: String) {
        #expect(result.message == message)
    }
}
