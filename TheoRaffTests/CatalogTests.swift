import Foundation
import Testing
@testable import TheoRaff

struct CatalogTests {
    private let shades = #"{"id": "shades", "name": "Tinted Shades", "category": "eyewear", "imageName": "shades", "modelName": "shades", "searchQuery": "y2k tinted shades"}"#
    private let cap = #"{"id": "cap", "name": "Trucker Cap", "category": "headwear", "imageName": "cap", "modelName": "cap", "searchQuery": "y2k trucker cap"}"#
    private let hoodie = #"{"id": "hoodie", "name": "Velour Hoodie", "category": "top", "imageName": "hoodie", "searchQuery": "y2k velour hoodie"}"#

    /// Builds catalog JSON from garment objects and outfits written as `id: [garment IDs]`.
    private func catalog(garments: [String], outfits: KeyValuePairs<String, [String]>) throws -> Catalog {
        let looks = outfits.map { id, garmentIDs in
            let ids = garmentIDs.map { "\"\($0)\"" }.joined(separator: ", ")
            return "{\"id\": \"\(id)\", \"name\": \"Look \(id)\", \"garmentIDs\": [\(ids)]}"
        }
        let json = "{\"garments\": [\(garments.joined(separator: ", "))], \"outfits\": [\(looks.joined(separator: ", "))]}"
        return try Catalog(data: Data(json.utf8))
    }

    @Test func buildsOutfitsFromGarmentIDs() throws {
        let catalog = try catalog(garments: [shades, hoodie], outfits: ["look": ["hoodie", "shades"]])
        #expect(catalog.garments.map(\.id) == ["shades", "hoodie"])
        let look = try #require(catalog.outfits.first)
        #expect(look.id == "look")
        #expect(look.name == "Look look")
        #expect(look.garments.map(\.id) == ["hoodie", "shades"])
    }

    /// The Try On deck: one card per item the camera can put on you. Clothes are left to the AI.
    @Test func liveDeckHasOneCardPerFaceItem() throws {
        let catalog = try catalog(garments: [hoodie, shades, cap], outfits: ["look": ["hoodie", "shades"]])
        #expect(catalog.liveLooks.map(\.id) == ["shades", "cap"])
        #expect(catalog.liveLooks.map(\.name) == ["Tinted Shades", "Trucker Cap"])
        #expect(catalog.liveLooks.map { $0.garments.map(\.id) } == [["shades"], ["cap"]])
    }

    @Test func oneGarmentCanBeInSeveralOutfits() throws {
        let catalog = try catalog(garments: [shades, hoodie], outfits: ["a": ["shades"], "b": ["hoodie", "shades"]])
        #expect(catalog.outfits.map(\.id) == ["a", "b"])
        #expect(catalog.outfits[0].garment(for: .eyewear) == catalog.outfits[1].garment(for: .eyewear))
    }

    @Test func keepsGarmentsThatAreInNoOutfit() throws {
        let catalog = try catalog(garments: [shades, hoodie], outfits: ["look": ["shades"]])
        #expect(catalog.garments.map(\.id) == ["shades", "hoodie"])
    }

    @Test func matchesGarmentIDsAfterTrimming() throws {
        let catalog = try catalog(garments: [hoodie], outfits: ["look": [" hoodie "]])
        #expect(catalog.outfits.first?.garments.map(\.id) == ["hoodie"])
    }

    @Test func rejectsAnOutfitWithAnUnknownGarment() {
        #expect(throws: CatalogError.unknownGarment("cap", outfitID: "look")) {
            try catalog(garments: [shades], outfits: ["look": ["shades", "cap"]])
        }
    }

    @Test func rejectsRepeatedGarmentIDs() {
        #expect(throws: CatalogError.duplicateGarmentID("shades")) {
            try catalog(garments: [shades, cap, shades], outfits: ["look": ["shades"]])
        }
    }

    @Test func rejectsRepeatedOutfitIDs() {
        #expect(throws: CatalogError.duplicateOutfitID("look")) {
            try catalog(garments: [shades, hoodie], outfits: ["look": ["shades"], "look": ["hoodie"]])
        }
    }

    @Test func appliesTheOutfitRules() {
        #expect(throws: OutfitError.noGarments(outfitID: "look")) {
            try catalog(garments: [shades], outfits: ["look": []])
        }
    }

    @Test func namesTheInvalidGarment() {
        let noModel = #"{"id": "shades", "name": "Tinted Shades", "category": "eyewear", "imageName": "shades", "searchQuery": "shades"}"#
        let error = #expect(throws: DecodingError.self) {
            try catalog(garments: [noModel], outfits: [:])
        }
        #expect(Fixtures.underlyingError(of: error) as? GarmentError == .missingModel(garmentID: "shades"))
    }

    @Test func rejectsMalformedJSON() {
        #expect(throws: DecodingError.self) {
            try Catalog(data: Data(#"{"garments": ["#.utf8))
        }
    }

    @Test func reportsAMissingFile() {
        #expect(throws: CatalogError.missingFile("no-such-catalog.json")) {
            try Catalog.load(named: "no-such-catalog")
        }
    }
}
