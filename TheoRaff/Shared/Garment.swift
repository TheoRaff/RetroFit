import Foundation

/// The kinds of clothing in the catalog. The category decides how a garment is tried on.
enum GarmentCategory: String, Codable, CaseIterable, Sendable {
    case eyewear
    case headwear
    case top
    case bottom
    case fullLook

    /// How the live camera view shows garments of this category.
    var liveStyle: LiveStyle {
        switch self {
        case .eyewear, .headwear: return .faceModel
        case .top: return .bodyCutout
        case .bottom, .fullLook: return .renderOnly
        }
    }
}

/// How a garment appears on the live camera view.
enum LiveStyle: Sendable {
    /// A 3D USDZ model on ARKit's face anchor.
    case faceModel
    /// A 2D cutout warped onto the shoulders and hips.
    case bodyCutout
    /// Not shown live. Appears only in an AI render.
    case renderOnly
}

enum GarmentError: Error, Equatable {
    case emptyField(String)
    case missingModel(garmentID: String)
}

/// One clothing item in the catalog. Text fields are trimmed of surrounding whitespace.
struct Garment: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let category: GarmentCategory
    /// Asset catalog image name, without an extension, for example `pink-velour-hoodie`.
    /// The product photo or background-removed cutout, used on cards, in the closet,
    /// for body overlays, and as the AI render input.
    let imageName: String
    /// USDZ file name in the app bundle, without the `.usdz` extension, for example
    /// `tinted-shades`. Load it with RealityKit's `Entity(named:)`.
    /// Always set for eyewear and headwear. Nil when blank.
    let modelName: String?
    /// Search text for the Depop, Vinted and eBay "Find it" links.
    let searchQuery: String
    /// Style tags such as "mcbling" or "skater", used for the era reveal.
    let tags: [String]

    init(
        id: String,
        name: String,
        category: GarmentCategory,
        imageName: String,
        modelName: String? = nil,
        searchQuery: String,
        tags: [String] = []
    ) throws {
        let cleanID = try Validation.requireText(id, field: "id", error: GarmentError.emptyField)
        let cleanModel = Validation.trimmedOrNil(modelName)
        if category.liveStyle == .faceModel && cleanModel == nil {
            throw GarmentError.missingModel(garmentID: cleanID)
        }
        self.id = cleanID
        self.name = try Validation.requireText(name, field: "name", error: GarmentError.emptyField)
        self.category = category
        self.imageName = try Validation.requireText(imageName, field: "imageName", error: GarmentError.emptyField)
        self.modelName = cleanModel
        self.searchQuery = try Validation.requireText(searchQuery, field: "searchQuery", error: GarmentError.emptyField)
        self.tags = tags
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, category, imageName, modelName, searchQuery, tags
    }

    /// Decoding runs the same checks as the initialiser. A failure becomes a
    /// `DecodingError` that names the garment and its place in the JSON.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let id = try values.decode(String.self, forKey: .id)
        do {
            self = try Garment(
                id: id,
                name: values.decode(String.self, forKey: .name),
                category: values.decode(GarmentCategory.self, forKey: .category),
                imageName: values.decode(String.self, forKey: .imageName),
                modelName: values.decodeIfPresent(String.self, forKey: .modelName),
                searchQuery: values.decode(String.self, forKey: .searchQuery),
                tags: values.decodeIfPresent([String].self, forKey: .tags) ?? []
            )
        } catch let error as GarmentError {
            throw Validation.decodingError(error, kind: "Garment", id: id, at: decoder.codingPath)
        }
    }
}

/// Shared input checks for the catalog types.
enum Validation {
    static func trimmedOrNil(_ text: String?) -> String? {
        let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Returns the trimmed text, or throws the given error when it is blank.
    static func requireText<E: Error>(_ text: String, field: String, error: (String) -> E) throws -> String {
        guard let trimmed = trimmedOrNil(text) else {
            throw error(field)
        }
        return trimmed
    }

    /// The first value that appears more than once, if any.
    static func firstRepeat<T: Hashable>(in values: [T]) -> T? {
        var seen = Set<T>()
        return values.first { !seen.insert($0).inserted }
    }

    static func decodingError(_ error: Error, kind: String, id: String, at path: [CodingKey]) -> DecodingError {
        DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: path,
            debugDescription: "\(kind) \"\(id)\" is invalid: \(error)",
            underlyingError: error
        ))
    }
}
