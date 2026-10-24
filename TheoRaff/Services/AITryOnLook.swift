import Foundation

/// What one AI try-on puts on you: a title for the screen and the garments to render, in order.
/// Each garment is its own render, drawn onto the result of the one before.
struct AITryOnLook: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    /// Render order: clothes first (a full look, the top, the bottoms), then shoes and the
    /// accessories that sit over them (a hat, then glasses).
    let garments: [Garment]

    var pieceCount: Int { garments.count }

    /// One garment, whatever it is.
    init(garment: Garment) {
        self.init(id: garment.id, title: garment.name, garments: [garment])
    }

    /// A look from the deck, every piece in it, accessories included, since the AI camera's
    /// photo doesn't have the live view's 3D glasses on it.
    init(outfit: Outfit) {
        self.init(id: outfit.id, title: outfit.name, garments: Self.renderOrder(outfit.garments))
    }

    /// A mix of garments, such as the closet's fitting room.
    init(title: String, garments: [Garment]) {
        let id = garments.map(\.id).joined(separator: "+")
        self.init(id: id, title: title, garments: Self.renderOrder(garments))
    }

    private init(id: String, title: String, garments: [Garment]) {
        self.id = id
        self.title = title
        self.garments = garments
    }

    /// Bigger pieces go on first so the smaller ones layer over them.
    private static func renderOrder(_ garments: [Garment]) -> [Garment] {
        let rank: [GarmentCategory: Int] = [.fullLook: 0, .top: 1, .bottom: 2, .shoes: 3, .headwear: 4, .eyewear: 5]
        return garments.enumerated()
            .sorted { ((rank[$0.element.category] ?? 9), $0.offset) < ((rank[$1.element.category] ?? 9), $1.offset) }
            .map(\.element)
    }
}
