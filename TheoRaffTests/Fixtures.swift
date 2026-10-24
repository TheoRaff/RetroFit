import Foundation
@testable import TheoRaff

/// Small builders so each test only states what it cares about.
enum Fixtures {
    static func garment(
        id: String,
        category: GarmentCategory = .top,
        modelName: String? = nil
    ) throws -> Garment {
        let needsModel = category.liveStyle == .faceModel
        return try Garment(
            id: id,
            name: "Garment \(id)",
            category: category,
            imageName: "\(id)-photo",
            modelName: modelName ?? (needsModel ? id : nil),
            searchQuery: "y2k \(id)",
            tags: ["mcbling"]
        )
    }

    static func outfit(id: String, garments: [Garment]) throws -> Outfit {
        try Outfit(id: id, name: "Outfit \(id)", garments: garments)
    }

    /// An outfit with one garment, the simplest card in the deck.
    static func outfit(id: String, category: GarmentCategory = .top) throws -> Outfit {
        try outfit(id: id, garments: [garment(id: "\(id)-item", category: category)])
    }

    /// The validation error a decoder wrapped inside a `DecodingError`.
    static func underlyingError(of error: DecodingError?) -> Error? {
        guard case .dataCorrupted(let context)? = error else { return nil }
        return context.underlyingError
    }
}
