import Foundation
import os

enum CatalogError: Error, Equatable {
    case missingFile(String)
    case duplicateGarmentID(String)
    case duplicateOutfitID(String)
    case unknownGarment(String, outfitID: String)
}

/// Every garment in the app and the looks in the try-on deck, read from `catalog.json`.
///
/// The file lists each garment once, and each outfit names its garments by id:
///
///     {
///       "garments": [
///         {"id": "white-shades", "name": "White Shades", "category": "eyewear",
///          "imageName": "white-shades", "modelName": "White_sunglasses",
///          "searchQuery": "y2k white sunglasses", "tags": ["mcbling"]}
///       ],
///       "outfits": [
///         {"id": "white-shades-look", "name": "White Shades", "garmentIDs": ["white-shades"]}
///       ]
///     }
///
/// A garment can be in several outfits, or in none, in which case it only shows in the closet.
struct Catalog: Equatable, Sendable {
    /// Every garment, in file order. The closet shows these.
    let garments: [Garment]
    /// Outfits from the file, in file order.
    let outfits: [Outfit]
    /// The Try On deck: one look per garment the camera can put on you live (glasses and
    /// hats), in file order. Clothes can't be shown live, so they're tried on with AI from the closet.
    let liveLooks: [Outfit]

    /// The catalog that ships in the app, loaded once. Empty, with the error logged,
    /// when catalog.json is missing or invalid. It doesn't crash, so the app still opens
    /// as the test host and `BundledCatalogTests` can name the problem.
    static let bundled: Catalog = {
        do {
            return try load()
        } catch {
            logger.error("catalog.json didn't load: \(String(describing: error), privacy: .public)")
            return Catalog(garments: [], outfits: [])
        }
    }()

    /// Reads catalog JSON. Garments and outfits get their usual checks as they decode,
    /// IDs must be unique, and every garment ID in an outfit must name a garment in the file.
    init(data: Data) throws {
        let file = try JSONDecoder().decode(CatalogFile.self, from: data)
        if let repeated = Validation.firstRepeat(in: file.garments.map(\.id)) {
            throw CatalogError.duplicateGarmentID(repeated)
        }
        let garmentsByID = Dictionary(uniqueKeysWithValues: file.garments.map { ($0.id, $0) })
        let outfits = try file.outfits.map { try $0.outfit(from: garmentsByID) }
        if let repeated = Validation.firstRepeat(in: outfits.map(\.id)) {
            throw CatalogError.duplicateOutfitID(repeated)
        }
        self.init(garments: file.garments, outfits: outfits)
    }

    /// Loads `<name>.json` from the bundle.
    static func load(named name: String = "catalog", from bundle: Bundle = .main) throws -> Catalog {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw CatalogError.missingFile("\(name).json")
        }
        return try Catalog(data: Data(contentsOf: url))
    }

    private init(garments: [Garment], outfits: [Outfit]) {
        self.garments = garments
        self.outfits = outfits
        self.liveLooks = garments
            .filter { $0.category.liveStyle == .faceModel }
            .compactMap { try? Outfit(id: $0.id, name: $0.name, garments: [$0]) }
    }
}

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TheoRaff", category: "Catalog")

/// The JSON shape: garments in full, outfits by garment id.
private struct CatalogFile: Decodable {
    let garments: [Garment]
    let outfits: [OutfitEntry]
}

private struct OutfitEntry: Decodable {
    let id: String
    let name: String
    let garmentIDs: [String]

    /// The outfit with its garments looked up by id. `Outfit` checks the rest.
    func outfit(from garmentsByID: [String: Garment]) throws -> Outfit {
        let outfitID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let garments = try garmentIDs.map { rawID in
            let garmentID = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let garment = garmentsByID[garmentID] else {
                throw CatalogError.unknownGarment(garmentID, outfitID: outfitID)
            }
            return garment
        }
        return try Outfit(id: id, name: name, garments: garments)
    }
}
