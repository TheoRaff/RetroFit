import Foundation
import Testing
@testable import TheoRaff

struct OutfitTests {
    @Test func needsAtLeastOneGarment() {
        #expect(throws: OutfitError.noGarments(outfitID: "empty")) {
            try Outfit(id: "empty", name: "Empty", garments: [])
        }
    }

    @Test func allowsOnlyOneGarmentPerCategory() throws {
        let first = try Fixtures.garment(id: "tee-1")
        let second = try Fixtures.garment(id: "tee-2")
        #expect(throws: OutfitError.duplicateCategory(.top, outfitID: "double")) {
            try Outfit(id: "double", name: "Double Top", garments: [first, second])
        }
    }

    @Test func rejectsBlankName() throws {
        let tee = try Fixtures.garment(id: "tee")
        #expect(throws: OutfitError.emptyField("name")) {
            try Outfit(id: "look", name: " ", garments: [tee])
        }
    }

    @Test func findsGarmentByCategory() throws {
        let shades = try Fixtures.garment(id: "shades", category: .eyewear)
        let hoodie = try Fixtures.garment(id: "hoodie", category: .top)
        let look = try Fixtures.outfit(id: "look", garments: [shades, hoodie])
        #expect(look.garment(for: .eyewear) == shades)
        #expect(look.garment(for: .top) == hoodie)
        #expect(look.garment(for: .bottom) == nil)
    }

    @Test func decodingValidatesLikeTheInitialiser() {
        let tee = """
        {"id":"tee","name":"Tee","category":"top","imageName":"tee","searchQuery":"tee"}
        """
        let json = """
        {"id":"look","name":"Look","garments":[\(tee),\(tee)]}
        """
        let error = #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Outfit.self, from: Data(json.utf8))
        }
        #expect(Fixtures.underlyingError(of: error) as? OutfitError == .duplicateCategory(.top, outfitID: "look"))
    }

    @Test func rejectsTwoGarmentsWithTheSameID() throws {
        let shades = try Fixtures.garment(id: "same", category: .eyewear)
        let tee = try Fixtures.garment(id: "same", category: .top)
        #expect(throws: OutfitError.duplicateGarmentID("same", outfitID: "look")) {
            try Outfit(id: "look", name: "Look", garments: [shades, tee])
        }
    }

    @Test func decodeErrorNamesTheBadGarmentAndWhereItIs() {
        let good = """
        {"id":"tee","name":"Tee","category":"top","imageName":"tee","searchQuery":"tee"}
        """
        let bad = """
        {"id":"bad-shades","name":"Shades","category":"eyewear","imageName":"shades","searchQuery":"shades"}
        """
        let json = """
        [{"id":"one","name":"One","garments":[\(good)]},
         {"id":"two","name":"Two","garments":[\(bad)]}]
        """
        let error = #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([Outfit].self, from: Data(json.utf8))
        }
        guard case .dataCorrupted(let context)? = error else {
            Issue.record("Expected a dataCorrupted error")
            return
        }
        #expect(context.debugDescription.contains("bad-shades"))
        #expect(context.codingPath.map(\.stringValue) == ["Index 1", "garments", "Index 0"])
    }
}
