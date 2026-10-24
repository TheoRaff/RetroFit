import Foundation
import Testing
import UIKit
@testable import TheoRaff

struct RenderImageEncoderTests {
    private func solidImage(width: CGFloat, height: CGFloat, color: UIColor = .red, opaque: Bool = true) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = opaque
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    private func decode(_ dataURI: String) throws -> UIImage {
        let prefix = "data:image/jpeg;base64,"
        #expect(dataURI.hasPrefix(prefix))
        let data = try #require(Data(base64Encoded: String(dataURI.dropFirst(prefix.count))))
        return try #require(UIImage(data: data))
    }

    @Test func shrinksLargePhotosToTheMaximumSide() throws {
        let image = try decode(RenderImageEncoder.dataURI(for: solidImage(width: 3000, height: 2000)))
        #expect(max(image.size.width, image.size.height) == RenderImageEncoder.maxDimension)
        #expect(abs(image.size.width / image.size.height - 1.5) < 0.01)
    }

    @Test func leavesSmallPhotosAtTheirSize() throws {
        let image = try decode(RenderImageEncoder.dataURI(for: solidImage(width: 400, height: 600)))
        #expect(image.size == CGSize(width: 400, height: 600))
    }

    @Test func staysUnderTheFunctionsSizeLimit() throws {
        let dataURI = try RenderImageEncoder.dataURI(for: solidImage(width: 4000, height: 4000))
        #expect(dataURI.utf8.count < RenderImageEncoder.maxBytes * 4 / 3 + 100)
    }

    @Test func putsTransparentCutoutsOnWhite() throws {
        let clear = solidImage(width: 10, height: 10, color: .clear, opaque: false)
        let image = try decode(RenderImageEncoder.dataURI(for: clear))
        let pixel = try #require(image.cgImage?.dataProvider?.data as Data?)
        #expect(pixel.prefix(3).allSatisfy { $0 > 240 })
    }

    @Test func rejectsAnEmptyImage() {
        #expect(throws: RenderError.imageEncodingFailed) {
            try RenderImageEncoder.dataURI(for: UIImage())
        }
    }
}
