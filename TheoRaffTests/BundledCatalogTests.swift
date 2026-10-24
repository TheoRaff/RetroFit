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

    @Test func hasTopsAndBottomsToRender() {
        let categories = Set(catalog.garments.map(\.category))
        #expect(categories.isSuperset(of: [.top, .bottom]))
    }

    /// The closet shows this photo and the AI try-on sends it, so every garment needs one.
    @Test func everyGarmentHasAProductPhoto() {
        for garment in catalog.garments {
            #expect(UIImage(named: garment.imageName) != nil, "No product photo for \(garment.id)")
        }
    }

    /// tools/prep-garment.swift draws every cutout on the shared canvas.
    @Test func productPhotosUseTheSharedCanvas() {
        for garment in catalog.garments {
            guard let image = UIImage(named: garment.imageName) else { continue }
            let pixels = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
            #expect(pixels == GarmentCanvas.size, "\(garment.id) is \(pixels), not on the shared canvas")
        }
    }

    @Test func shipsNoTestGarments() {
        #expect(catalog.garments.filter { $0.tags.contains("test") }.map(\.id) == [])
    }

    @Test func canvasShouldersAreLevelAndCentred() {
        let middle = (GarmentCanvas.leftShoulder.x + GarmentCanvas.rightShoulder.x) / 2
        #expect(GarmentCanvas.leftShoulder.y == GarmentCanvas.rightShoulder.y)
        #expect(middle == GarmentCanvas.size.width / 2)
    }
}
