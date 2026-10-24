import Observation
import UIKit

/// Garment photos with their transparent margins cut off, so they fill cards and thumbnails.
/// The shipped photos sit on the shared `GarmentCanvas`, which leaves room around every garment.
///
/// Trimming happens off the main thread in `preload`. Until a photo is trimmed, `named` returns
/// the untrimmed one, and views showing it redraw once the trimmed version is ready.
@MainActor
enum ProductPhoto {
    private static let cache = TrimmedPhotoCache()

    /// The trimmed photo if it's ready, otherwise the asset catalog photo as it is.
    /// Nil when there's no such photo.
    static func named(_ name: String) -> UIImage? {
        cache.trimmedByName[name] ?? UIImage(named: name)
    }

    /// Trims each photo once, in order, in the background.
    static func preload(_ names: [String]) async {
        for name in names where cache.trimmedByName[name] == nil {
            guard let photo = UIImage(named: name) else { continue }
            let trimmed = await Task.detached(priority: .userInitiated) {
                ImageTrimmer.trimmed(photo)
            }.value
            cache.trimmedByName[name] = trimmed
        }
    }
}

/// Trimmed photos by asset name. Observable, so views showing a photo redraw when it's trimmed.
@Observable
private final class TrimmedPhotoCache {
    var trimmedByName: [String: UIImage] = [:]
}

/// Finds and crops away an image's fully transparent border.
enum ImageTrimmer {
    /// Alpha at or below this counts as transparent, so faint edge noise doesn't stop the trim.
    static let alphaThreshold: UInt8 = 8

    /// The smallest rectangle, in pixels from the top-left, that holds every visible pixel.
    /// Nil when the image is completely transparent.
    static func opaqueBounds(of image: CGImage) -> CGRect? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            let row = y * width * 4
            for x in 0..<width where pixels[row + x * 4 + 3] > alphaThreshold {
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// The image cropped to its visible pixels. Returns the image unchanged when there's
    /// nothing to trim or it can't be read.
    static func trimmed(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage,
              let bounds = opaqueBounds(of: cgImage),
              bounds.size != CGSize(width: cgImage.width, height: cgImage.height),
              let cropped = cgImage.cropping(to: bounds) else {
            return image
        }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }
}
