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

    /// Try On only shows what the camera can put on you: every pair of glasses and every hat.
    @Test func liveDeckIsEveryARItemAndNothingElse() {
        let faceItems = catalog.garments.filter { $0.category.liveStyle == .faceModel }
        #expect(catalog.liveLooks.flatMap(\.garments) == faceItems)
        #expect(catalog.liveLooks.count >= 6)
    }

    /// A deck look shows glasses or a hat, not both. Both together only when someone picks them.
    @Test func deckLooksWearOneFaceItem() {
        for outfit in catalog.outfits {
            let faceItems = outfit.garments.filter { $0.category.liveStyle == .faceModel }
            #expect(faceItems.count <= 1, "\(outfit.id) wears \(faceItems.map(\.id))")
        }
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

    /// The script can't import the app, so it keeps its own copy of the canvas numbers.
    /// Runs in the simulator, where the repo is readable; skipped on a phone.
    @Test(.enabled(if: FileManager.default.fileExists(atPath: BundledCatalogTests.prepScriptPath)))
    func prepScriptUsesTheSameCanvas() throws {
        let script = try String(contentsOfFile: Self.prepScriptPath, encoding: .utf8)
        let canvas = [
            "static let width = \(Int(GarmentCanvas.size.width))",
            "static let height = \(Int(GarmentCanvas.size.height))",
            "static let leftShoulder = CGPoint(x: \(Int(GarmentCanvas.leftShoulder.x)), y: \(Int(GarmentCanvas.leftShoulder.y)))",
            "static let rightShoulder = CGPoint(x: \(Int(GarmentCanvas.rightShoulder.x)), y: \(Int(GarmentCanvas.rightShoulder.y)))",
        ]
        for line in canvas {
            #expect(script.contains(line), "tools/prep-garment.swift doesn't have \(line)")
        }
    }

    static let prepScriptPath = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("tools/prep-garment.swift")
        .path
}
