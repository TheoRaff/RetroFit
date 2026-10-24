import Foundation
import Testing
import UIKit
@testable import TheoRaff

struct SampleCatalogTests {
    private let outfits = SampleCatalog.outfits()

    @Test func hasOutfitsToSwipeThrough() {
        #expect(outfits.count >= 2)
    }

    @Test func outfitIDsAreUnique() {
        #expect(Set(outfits.map(\.id)).count == outfits.count)
    }

    @Test func garmentIDsAreUniqueAcrossTheCatalog() {
        let garments = outfits.flatMap(\.garments)
        #expect(Set(garments.map(\.id)).count == garments.count)
    }

    @Test func includesBothGlassesModels() {
        let models = Set(outfits.compactMap { $0.garment(for: .eyewear)?.modelName })
        #expect(models.isSuperset(of: ["Y2K_Sport_Sunglass", "White_sunglasses"]))
    }

    @Test func everyFaceModelShipsInTheApp() {
        let modelNames = outfits.flatMap(\.garments).compactMap(\.modelName)
        for name in modelNames {
            #expect(Bundle.main.url(forResource: name, withExtension: "usdz") != nil, "Missing \(name).usdz")
        }
    }

    @Test func startsASessionOnTheFirstOutfit() async {
        let session = await TryOnSession(outfits: outfits)
        let firstID = await session.currentOutfit?.id
        #expect(firstID == outfits.first?.id)
    }

    @Test func testTeeHasAProductPhotoForAITryOn() throws {
        let tee = try #require(outfits.flatMap(\.garments).first { $0.id == "fal-test-tee" })
        #expect(UIImage(named: tee.imageName) != nil)
    }
}

