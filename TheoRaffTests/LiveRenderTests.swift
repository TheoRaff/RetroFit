import Foundation
import Testing
import UIKit
@testable import TheoRaff

/// One real render through the Vercel function and fal.ai. It costs about $0.04,
/// so it only runs when asked:
///   TEST_RUNNER_RUN_LIVE_RENDER=1 xcodebuild test -project TheoRaff.xcodeproj -scheme TheoRaff \
///     -destination '<simulator>' -only-testing:TheoRaffTests/LiveRenderTests
/// It needs RENDER_API_TOKEN set in Config/Local.xcconfig.
struct LiveRenderTests {
    /// fal.ai's own example photos for this model.
    private let personURL = URL(string: "https://v3.fal.media/files/tiger/4vxSHizex4UWR5fdnPs1A.jpeg")!
    private let clothingURL = URL(string: "https://v3b.fal.media/files/b/monkey/5ZWXSKUuk9EilI1apFCeu_1ecd050187f24b9aa1d2defb88d8d8ae.png")!

    private func downloadImage(_ url: URL) async throws -> UIImage {
        let (data, _) = try await URLSession.shared.data(from: url)
        return try #require(UIImage(data: data))
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["RUN_LIVE_RENDER"] == "1"), .timeLimit(.minutes(3)))
    func rendersARealTryOn() async throws {
        let service = RenderService(config: try RenderConfig.fromBundle())
        let person = try await downloadImage(personURL)
        let clothing = try await downloadImage(clothingURL)

        let resultURL = try await service.render(person: person, clothing: clothing) { status in
            print("Live render status: \(status)")
        }
        print("Live render result: \(resultURL)")

        #expect(resultURL.scheme == "https")
        let (data, _) = try await URLSession.shared.data(from: resultURL)
        let rendered = try #require(UIImage(data: data))
        #expect(rendered.size.width > 0)

        // Kept in the test results so the render can be looked at afterwards.
        Attachment.record(data, named: "live-render.png")
        Attachment.record(Data(resultURL.absoluteString.utf8), named: "live-render-url.txt")
    }
}
