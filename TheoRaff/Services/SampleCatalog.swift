import Foundation

/// Placeholder looks until the real catalog JSON lands.
/// The eyewear uses the USDZ models in Resources.
enum SampleCatalog {
    static func outfits() -> [Outfit] {
        do {
            return try [
                Outfit(id: "sport-shades-look", name: "Sport Shades", garments: [
                    Garment(
                        id: "y2k-sport-shades", name: "Y2K Sport Shades", category: .eyewear,
                        imageName: "y2k-sport-shades", modelName: "Y2K_Sport_Sunglass",
                        searchQuery: "y2k sport wrap sunglasses", tags: ["sporty", "mcbling"]
                    ),
                ]),
                Outfit(id: "white-shades-look", name: "White Shades", garments: [
                    Garment(
                        id: "white-shades", name: "White Shades", category: .eyewear,
                        imageName: "white-shades", modelName: "White_sunglasses",
                        searchQuery: "y2k white sunglasses", tags: ["mcbling"]
                    ),
                ]),
                Outfit(id: "velour-hoodie-look", name: "Pink Velour Hoodie", garments: [
                    Garment(
                        id: "pink-velour-hoodie", name: "Pink Velour Hoodie", category: .top,
                        imageName: "pink-velour-hoodie",
                        searchQuery: "y2k pink velour zip hoodie", tags: ["mcbling"]
                    ),
                ]),
            ]
        } catch {
            assertionFailure("SampleCatalog is invalid: \(error)")
            return []
        }
    }
}
