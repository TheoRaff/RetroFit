import Testing
@testable import TheoRaff

struct AITryOnLookTests {
    private let jersey = try! Fixtures.garment(id: "jersey", category: .top)
    private let jeans = try! Fixtures.garment(id: "jeans", category: .bottom)
    private let shades = try! Fixtures.garment(id: "shades", category: .eyewear)
    private let dress = try! Fixtures.garment(id: "dress", category: .fullLook)

    @Test func aSingleGarmentIsRenderedWhateverItIs() {
        let look = AITryOnLook(garment: shades)
        #expect(look.garments == [shades])
        #expect(look.title == shades.name)
    }

    @Test func anOutfitRendersItsClothesTopFirstAndLeavesTheShadesToTheLiveView() throws {
        let outfit = try Fixtures.outfit(id: "court-kings", garments: [shades, jeans, jersey])
        let look = AITryOnLook(outfit: outfit)
        #expect(look.garments == [jersey, jeans])
        #expect(look.title == outfit.name)
    }

    @Test func anOutfitOfOnlyShadesStillRendersThem() throws {
        let outfit = try Fixtures.outfit(id: "shades-only", garments: [shades])
        #expect(AITryOnLook(outfit: outfit).garments == [shades])
    }

    @Test func aFullLookGoesOnBeforeTopsAndBottoms() {
        let look = AITryOnLook(title: "Mix", garments: [jeans, jersey, dress])
        #expect(look.garments == [dress, jersey, jeans])
    }

    @Test func describesHowManyRendersItTakes() throws {
        let outfit = try Fixtures.outfit(id: "court-kings", garments: [jersey, jeans])
        #expect(AITryOnLook(outfit: outfit).pieceCount == 2)
        #expect(AITryOnLook(garment: jersey).pieceCount == 1)
    }
}
