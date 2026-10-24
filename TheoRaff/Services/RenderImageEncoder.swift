import UIKit

/// Turns photos into the JPEG data URIs the render function accepts.
enum RenderImageEncoder {
    /// Longest side sent to the function. Plenty for try-on, and keeps uploads quick.
    static let maxDimension: CGFloat = 1024
    /// Stays under the function's 1.5 MB per-image limit.
    static let maxBytes = 1_400_000
    private static let qualities: [CGFloat] = [0.85, 0.7, 0.55, 0.4]

    static func dataURI(for image: UIImage) throws -> String {
        guard image.size.width > 0, image.size.height > 0 else {
            throw RenderError.imageEncodingFailed
        }
        let prepared = flattened(image)
        for quality in qualities {
            guard let data = prepared.jpegData(compressionQuality: quality) else {
                throw RenderError.imageEncodingFailed
            }
            if data.count <= maxBytes {
                return "data:image/jpeg;base64," + data.base64EncodedString()
            }
        }
        throw RenderError.imageTooLarge
    }

    /// Scales the image down to `maxDimension` and draws it on white, so
    /// transparent cutouts don't turn black when saved as JPEG.
    private static func flattened(_ image: UIImage) -> UIImage {
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
