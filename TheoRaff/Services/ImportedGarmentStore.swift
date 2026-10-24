import ImageIO
import Observation
import UIKit

/// Personal clothing lives in Application Support, separate from the bundled AR catalog.
@MainActor
@Observable
final class ImportedGarmentStore {
    static let shared = ImportedGarmentStore(directory: URL.applicationSupportDirectory
        .appendingPathComponent("ImportedClothes", isDirectory: true))

    static let categories: [GarmentCategory] = [.top, .bottom, .fullLook, .shoes]
    private(set) var garments: [Garment] = []
    private(set) var loadError: String?
    private let directory: URL
    private var manifest: URL { directory.appendingPathComponent("garments.json") }

    enum ImportError: LocalizedError {
        case invalidPhoto, invalidCategory
        var errorDescription: String? {
            switch self {
            case .invalidPhoto: "Couldn't open that clothing photo. Try another."
            case .invalidCategory: "Choose a top, bottoms, shoes or a full look."
            }
        }
    }

    init(directory: URL) {
        self.directory = directory
        guard FileManager.default.fileExists(atPath: manifest.path) else { return }
        do {
            let saved = try JSONDecoder().decode([Garment].self, from: Data(contentsOf: manifest))
            garments = saved.filter {
                Self.categories.contains($0.category) && photo(named: $0.imageName) != nil
            }
        } catch {
            loadError = "Your imported clothes couldn't be loaded. Please try reopening the app."
        }
    }

    /// Downsample before decoding large library images, apply their orientation, and use the
    /// same product canvas as the catalog. This photo is the clothing input, never the person.
    nonisolated static func preparePhoto(data: Data) throws -> UIImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1536,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw ImportError.invalidPhoto }
        let photo = UIImage(cgImage: image)
        let canvas = GarmentCanvas.size
        let scale = min(canvas.width * 0.9 / photo.size.width, canvas.height * 0.9 / photo.size.height)
        let size = CGSize(width: photo.size.width * scale, height: photo.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: canvas, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: canvas))
            photo.draw(in: CGRect(x: (canvas.width - size.width) / 2,
                                  y: (canvas.height - size.height) / 2,
                                  width: size.width, height: size.height))
        }
    }

    @discardableResult
    func add(photo: UIImage, name: String, category: GarmentCategory) throws -> Garment {
        guard loadError == nil else { throw CocoaError(.fileReadCorruptFile) }
        guard Self.categories.contains(category) else { throw ImportError.invalidCategory }
        let id = UUID().uuidString.lowercased()
        let garment = try Garment(id: "imported-\(id)", name: name, category: category,
                                  imageName: "imported-\(id)", searchQuery: name, tags: ["your-clothes"])
        guard let data = photo.pngData(), let photoURL = photoURL(named: garment.imageName) else {
            throw ImportError.invalidPhoto
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: photoURL, options: .atomic)
        let updated = [garment] + garments
        do {
            try JSONEncoder().encode(updated).write(to: manifest, options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: photoURL)
            throw error
        }
        garments = updated
        return garment
    }

    func photo(named name: String) -> UIImage? {
        guard let url = photoURL(named: name) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private func photoURL(named name: String) -> URL? {
        guard name.hasPrefix("imported-"), UUID(uuidString: String(name.dropFirst(9))) != nil else { return nil }
        return directory.appendingPathComponent(name).appendingPathExtension("png")
    }
}
