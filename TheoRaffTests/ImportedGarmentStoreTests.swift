import Foundation
import Testing
import UIKit
@testable import TheoRaff

@MainActor
struct ImportedGarmentStoreTests {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func photo(_ color: UIColor = .red) throws -> UIImage {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 80)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 80))
        }
        return try ImportedGarmentStore.preparePhoto(data: #require(image.pngData()))
    }

    @Test func clothingAndItsProductPhotoSurviveReopening() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ImportedGarmentStore(directory: directory)
        let image = try photo()
        let garment = try store.add(photo: image, name: "  My red top  ", category: .top)
        let reopened = ImportedGarmentStore(directory: directory)

        #expect(reopened.garments == [garment])
        #expect(garment.name == "My red top")
        #expect(garment.modelName == nil)
        let savedPhoto = try #require(reopened.photo(named: garment.imageName))
        #expect(savedPhoto.size == GarmentCanvas.size)
        #expect(savedPhoto.pngData() == image.pngData())
    }

    @Test func clothesWithTheSameNameKeepTheirOwnPhotos() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ImportedGarmentStore(directory: directory)
        let first = try store.add(photo: photo(.red), name: "My top", category: .top)
        let second = try store.add(photo: photo(.blue), name: "My top", category: .top)
        #expect(first.id != second.id)
        #expect(first.imageName != second.imageName)
        #expect(store.photo(named: first.imageName)?.pngData() != store.photo(named: second.imageName)?.pngData())
    }

    @Test func rejectsUnreadablePhotoData() {
        #expect(throws: ImportedGarmentStore.ImportError.self) {
            try ImportedGarmentStore.preparePhoto(data: Data("not a photo".utf8))
        }
    }

    @Test func importedPhotosDoNotCreateARAccessoriesWithoutModels() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ImportedGarmentStore(directory: directory)
        let image = try photo()
        #expect(throws: ImportedGarmentStore.ImportError.self) {
            try store.add(photo: image, name: "Glasses", category: .eyewear)
        }
        #expect(store.garments.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test func blankNamesDoNotSaveAnItem() throws {
        let directory = temporaryDirectory()
        let store = ImportedGarmentStore(directory: directory)
        let image = try photo()
        #expect(throws: GarmentError.self) {
            try store.add(photo: image, name: "  ", category: .top)
        }
        #expect(store.garments.isEmpty)
    }

    @Test func photoNamesCannotReadOutsideTheImportDirectory() {
        let store = ImportedGarmentStore(directory: temporaryDirectory())
        #expect(store.photo(named: "../catalog") == nil)
        #expect(store.photo(named: "imported-../../catalog") == nil)
    }

    @Test func unreadableManifestIsPreservedInsteadOfOverwritten() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let manifest = directory.appendingPathComponent("garments.json")
        let corrupt = Data("damaged manifest".utf8)
        try corrupt.write(to: manifest)
        let store = ImportedGarmentStore(directory: directory)
        let image = try photo()
        #expect(store.loadError != nil)
        #expect(throws: CocoaError.self) {
            try store.add(photo: image, name: "My top", category: .top)
        }
        #expect(try Data(contentsOf: manifest) == corrupt)
    }

    @Test func failedDiskWriteDoesNotAddAnItem() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("a file instead of a directory".utf8).write(to: directory)
        let store = ImportedGarmentStore(directory: directory)
        let image = try photo()
        #expect(throws: (any Error).self) {
            try store.add(photo: image, name: "My top", category: .top)
        }
        #expect(store.garments.isEmpty)
    }
}
