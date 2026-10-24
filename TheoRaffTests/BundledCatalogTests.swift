import Foundation
import Testing
import UIKit
@testable import TheoRaff

/// Checks the catalog.json that ships in the app.
struct BundledCatalogTests {
    private let catalog: Catalog

    init() throws {
        catalog = try Catalog.load()
    }

    @Test func appUsesTheBundledFile() {
        #expect(Catalog.bundled == catalog)
    }

    @Test func hasOutfitsToSwipeThrough() {
        #expect(catalog.outfits.count >= 2)
    }

    @Test func includesBothGlassesModels() {
        let models = Set(catalog.garments.compactMap(\.modelName))
        #expect(models.isSuperset(of: ["Y2K_Sport_Sunglass", "White_sunglasses"]))
    }

    @Test func everyFaceModelShipsInTheApp() {
        for name in catalog.garments.compactMap(\.modelName) {
            #expect(Bundle.main.url(forResource: name, withExtension: "usdz") != nil, "Missing \(name).usdz")
        }
    }

    @Test func everyGarmentHasFindItLinks() {
        for garment in catalog.garments {
            let links = Marketplace.allCases.compactMap { $0.searchURL(for: garment.searchQuery) }
            #expect(links.count == Marketplace.allCases.count, "Missing a Find it link for \(garment.id)")
        }
    }

    @Test func startsASessionOnTheFirstOutfit() async {
        let session = await TryOnSession(outfits: catalog.outfits)
        let firstID = await session.currentOutfit?.id
        #expect(firstID == catalog.outfits.first?.id)
    }

    @Test func testTeeHasAProductPhotoForAITryOn() throws {
        let tee = try #require(catalog.garments.first { $0.id == "fal-test-tee" })
        #expect(UIImage(named: tee.imageName) != nil)
    }
}
