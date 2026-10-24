import Testing
import UIKit
@testable import TheoRaff

struct ImageTrimmerTests {
    /// A transparent canvas with one opaque rectangle, measured from the top-left.
    private func canvas(width: Int, height: Int, opaque rect: CGRect?) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            if let rect {
                UIColor.systemPink.setFill()
                context.fill(rect)
            }
        }
    }

    @Test func findsTheOpaquePart() throws {
        let image = canvas(width: 100, height: 80, opaque: CGRect(x: 20, y: 10, width: 30, height: 40))
        let cgImage = try #require(image.cgImage)
        #expect(ImageTrimmer.opaqueBounds(of: cgImage) == CGRect(x: 20, y: 10, width: 30, height: 40))
    }

    @Test func cropsToTheOpaquePart() {
        let image = canvas(width: 100, height: 80, opaque: CGRect(x: 20, y: 10, width: 30, height: 40))
        let trimmed = ImageTrimmer.trimmed(image)
        #expect(trimmed.size == CGSize(width: 30, height: 40))
        #expect(trimmed.scale == image.scale)
    }

    @Test func leavesAFullyOpaqueImageAlone() {
        let image = canvas(width: 40, height: 20, opaque: CGRect(x: 0, y: 0, width: 40, height: 20))
        #expect(ImageTrimmer.trimmed(image).size == CGSize(width: 40, height: 20))
    }

    @Test func leavesAnEmptyImageAlone() throws {
        let image = canvas(width: 40, height: 20, opaque: nil)
        let cgImage = try #require(image.cgImage)
        #expect(ImageTrimmer.opaqueBounds(of: cgImage) == nil)
        #expect(ImageTrimmer.trimmed(image).size == CGSize(width: 40, height: 20))
    }

    @MainActor
    @Test func trimsShippedProductPhotos() async throws {
        let photo = try #require(UIImage(named: "pink-velour-hoodie"))
        await ProductPhoto.preload(["pink-velour-hoodie"])
        let trimmed = try #require(ProductPhoto.named("pink-velour-hoodie"))
        #expect(trimmed.size.width < photo.size.width)
        #expect(trimmed.size.height <= photo.size.height)
        #expect(ProductPhoto.named("no-such-photo") == nil)
    }
}
