import Foundation
import RealityKit
import Testing
@testable import TheoRaff

/// Hats are drawn around a reference head with the origin between the eyes,
/// so the AR view only moves them to the eyes and scales them.
struct HatFitTests {
    typealias HatFit = ARViewContainer.HatFit

    @Test func referenceHeadWearsTheHatAsBuilt() {
        #expect(HatFit.scale(eyeDistance: HatFit.referenceEyeDistance) == 1)
    }

    @Test func scalesWithTheWearersEyes() {
        #expect(abs(HatFit.scale(eyeDistance: 0.0693) - 1.1) < 0.0001)
    }

    @Test(arguments: [0.0, 0.02, 0.2, 5.0] as [Float])
    func badEyeReadingsStayInRange(eyeDistance: Float) {
        #expect(HatFit.scaleRange.contains(HatFit.scale(eyeDistance: eyeDistance)))
    }

    /// The occluder has to stay inside every hat, or it would cut holes in it.
    @Test func headOccluderFitsInsideTheHats() {
        #expect(HatFit.headCentre.y + HatFit.headRadii.y < 0.12)
        #expect(HatFit.headRadii.x < 0.08)
    }

    /// Each hat USDZ is in metres, sits over the eyes (origin), rises above them and faces +z.
    /// The clips, tiara, visor and hoops share the hat slot but not a hat's shape, so
    /// `AccessoryAssetTests` checks them instead.
    @MainActor
    @Test func everyHatModelIsBuiltAroundTheEyes() throws {
        let hats = try Catalog.load().garments.filter {
            $0.category == .headwear && !AccessoryAssetTests.models.contains($0.modelName ?? "")
        }
        #expect(hats.count >= 4)
        for hat in hats {
            let name = try #require(hat.modelName)
            let entity = try Entity.load(named: name)
            let bounds = entity.visualBounds(relativeTo: nil)
            #expect((0.15...0.32).contains(bounds.extents.x), "\(name) is \(bounds.extents.x) m wide")
            #expect(abs(bounds.center.x) < 0.01, "\(name) isn't centred between the eyes")
            #expect((0.10...0.22).contains(bounds.max.y), "\(name) top is at \(bounds.max.y) m")
            #expect(bounds.min.z < -0.15, "\(name) doesn't reach the back of the head")
            #expect(bounds.max.z > 0, "\(name) doesn't come forward to the forehead")
        }
    }
}
