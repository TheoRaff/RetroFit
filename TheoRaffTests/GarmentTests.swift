import Foundation
import Testing
@testable import TheoRaff

struct GarmentTests {
    @Test func topNeedsNoModel() throws {
        let tee = try Garment(
            id: "baby-tee", name: "Baby Tee", category: .top,
            imageName: "baby-tee", searchQuery: "y2k baby tee"
        )
        #expect(tee.modelName == nil)
        #expect(tee.tags.isEmpty)
    }

    @Test(arguments: [GarmentCategory.eyewear, .headwear])
    func faceItemsRequireAModel(category: GarmentCategory) {
        #expect(throws: GarmentError.missingModel(garmentID: "shades")) {
            try Garment(
                id: "shades", name: "Tinted Shades", category: category,
                imageName: "shades", searchQuery: "tinted shades"
            )
        }
    }

    @Test func blankModelNameCountsAsMissing() {
        #expect(throws: GarmentError.missingModel(garmentID: "cap")) {
            try Garment(
                id: "cap", name: "Trucker Cap", category: .headwear,
                imageName: "cap", modelName: "  ", searchQuery: "trucker cap"
            )
        }
    }

    @Test(arguments: ["id", "name", "imageName", "searchQuery"])
    func rejectsBlankRequiredText(field: String) {
        #expect(throws: GarmentError.emptyField(field)) {
            try Garment(
                id: field == "id" ? " " : "tee",
                name: field == "name" ? "" : "Tee",
                category: .top,
                imageName: field == "imageName" ? "\n" : "tee",
                searchQuery: field == "searchQuery" ? "" : "tee"
            )
        }
    }

    @Test(arguments: [
        (GarmentCategory.eyewear, LiveStyle.faceModel),
        (.headwear, .faceModel),
        (.top, .bodyCutout),
        (.bottom, .renderOnly),
        (.fullLook, .renderOnly),
    ])
    func categoryDecidesLiveStyle(category: GarmentCategory, style: LiveStyle) {
        #expect(category.liveStyle == style)
    }

    @Test func decodesCatalogJSON() throws {
        let json = """
        {"id":"shades","name":"Tinted Shades","category":"eyewear","imageName":"shades",
         "modelName":"shades","searchQuery":"y2k tinted shades","tags":["mcbling"]}
        """
        let shades = try JSONDecoder().decode(Garment.self, from: Data(json.utf8))
        #expect(shades.category == .eyewear)
        #expect(shades.modelName == "shades")
        #expect(shades.tags == ["mcbling"])
    }

    @Test func decodingDefaultsMissingTagsToEmpty() throws {
        let json = """
        {"id":"jeans","name":"Low-rise Jeans","category":"bottom","imageName":"jeans","searchQuery":"low rise jeans"}
        """
        let jeans = try JSONDecoder().decode(Garment.self, from: Data(json.utf8))
        #expect(jeans.tags.isEmpty)
        #expect(jeans.modelName == nil)
    }

    @Test func decodingValidatesLikeTheInitialiser() {
        let json = """
        {"id":"shades","name":"Tinted Shades","category":"eyewear","imageName":"shades","searchQuery":"shades"}
        """
        let error = #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Garment.self, from: Data(json.utf8))
        }
        #expect(Fixtures.underlyingError(of: error) as? GarmentError == .missingModel(garmentID: "shades"))
    }

    @Test func trimsSurroundingWhitespace() throws {
        let cap = try Garment(
            id: " cap ", name: " Trucker Cap\n", category: .headwear,
            imageName: " cap ", modelName: " trucker-cap ", searchQuery: " trucker cap "
        )
        #expect(cap.id == "cap")
        #expect(cap.name == "Trucker Cap")
        #expect(cap.imageName == "cap")
        #expect(cap.modelName == "trucker-cap")
        #expect(cap.searchQuery == "trucker cap")
    }

    @Test func blankModelNameBecomesNil() throws {
        let tee = try Garment(
            id: "tee", name: "Tee", category: .top,
            imageName: "tee", modelName: "  ", searchQuery: "tee"
        )
        #expect(tee.modelName == nil)
    }

    @Test func survivesAJSONRoundTrip() throws {
        let cap = try Fixtures.garment(id: "cap", category: .headwear)
        let data = try JSONEncoder().encode(cap)
        #expect(try JSONDecoder().decode(Garment.self, from: data) == cap)
    }
}
