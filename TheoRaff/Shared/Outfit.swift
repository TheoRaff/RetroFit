import Foundation

enum OutfitError: Error, Equatable {
    case emptyField(String)
    case noGarments(outfitID: String)
    case duplicateCategory(GarmentCategory, outfitID: String)
    case duplicateGarmentID(String, outfitID: String)
}

/// One look in the deck: one or more garments, at most one per category,
/// each with its own id. Text fields are trimmed of surrounding whitespace.
struct Outfit: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let garments: [Garment]

    init(id: String, name: String, garments: [Garment]) throws {
        let cleanID = try Validation.requireText(id, field: "id", error: OutfitError.emptyField)
        let cleanName = try Validation.requireText(name, field: "name", error: OutfitError.emptyField)
        if garments.isEmpty {
            throw OutfitError.noGarments(outfitID: cleanID)
        }
        if let repeated = Self.firstRepeat(in: garments.map(\.category)) {
            throw OutfitError.duplicateCategory(repeated, outfitID: cleanID)
        }
        if let repeated = Self.firstRepeat(in: garments.map(\.id)) {
            throw OutfitError.duplicateGarmentID(repeated, outfitID: cleanID)
        }
        self.id = cleanID
        self.name = cleanName
        self.garments = garments
    }

    /// The garment worn in this category, if the outfit has one.
    func garment(for category: GarmentCategory) -> Garment? {
        garments.first { $0.category == category }
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, garments
    }

    /// Decoding runs the same checks as the initialiser. A failure becomes a
    /// `DecodingError` that names the outfit and its place in the JSON.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let id = try values.decode(String.self, forKey: .id)
        do {
            self = try Outfit(
                id: id,
                name: values.decode(String.self, forKey: .name),
                garments: values.decode([Garment].self, forKey: .garments)
            )
        } catch let error as OutfitError {
            throw Validation.decodingError(error, kind: "Outfit", id: id, at: decoder.codingPath)
        }
    }

    private static func firstRepeat<T: Hashable>(in values: [T]) -> T? {
        var seen = Set<T>()
        return values.first { !seen.insert($0).inserted }
    }
}
