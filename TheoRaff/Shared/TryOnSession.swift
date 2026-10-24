import Observation

/// Shared state for the try-on screen, and the contract between tracking and the app.
///
/// - The app side moves between outfits with `showNext()`, `showPrevious()` or
///   `show(outfitID:)` (swipes), and saves items with `likeCurrentOutfit()`,
///   `toggleLikeCurrentOutfit()` or `like(_:)` (the Like button).
/// - The tracking side reads `currentOutfit` and draws its garments on the camera view.
///
/// Everything here runs on the main actor. Read it from SwiftUI views,
/// `UIViewRepresentable.updateUIView`, or `.onChange(of: session.currentOutfit)`.
/// Background code, such as ARSession delegates and Vision callbacks, cannot read the
/// session directly. Hand it a copy of the current `Outfit` from the main actor instead.
/// `Outfit` is `Sendable`, so the copy is safe to pass across threads.
@MainActor
@Observable
final class TryOnSession {
    private(set) var outfits: [Outfit]
    private(set) var currentIndex = 0
    /// Liked garments in the order they were liked, without duplicates.
    /// Garments are matched by id, so always check with `isLiked(_:)`.
    private(set) var closet: [Garment]

    init(outfits: [Outfit] = [], closet: [Garment] = []) {
        self.outfits = outfits
        self.closet = Self.withoutDuplicates(closet)
    }

    // MARK: Moving between outfits

    var currentOutfit: Outfit? {
        outfits.indices.contains(currentIndex) ? outfits[currentIndex] : nil
    }

    var canShowNext: Bool { currentIndex + 1 < outfits.count }
    var canShowPrevious: Bool { currentIndex > 0 }

    /// Moves to the next outfit. Returns false at the end of the deck.
    @discardableResult
    func showNext() -> Bool {
        guard canShowNext else { return false }
        currentIndex += 1
        return true
    }

    /// Moves to the previous outfit. Returns false at the start of the deck.
    @discardableResult
    func showPrevious() -> Bool {
        guard canShowPrevious else { return false }
        currentIndex -= 1
        return true
    }

    /// Jumps to an outfit, for paged views that can skip several at once.
    /// Returns false, and stays put, when no outfit has that id.
    @discardableResult
    func show(outfitID: Outfit.ID) -> Bool {
        guard let index = outfits.firstIndex(where: { $0.id == outfitID }) else { return false }
        currentIndex = index
        return true
    }

    /// Swaps in a new deck, for example once the catalog has loaded, and starts at its first outfit.
    func replaceOutfits(_ newOutfits: [Outfit]) {
        outfits = newOutfits
        currentIndex = 0
    }

    // MARK: Liking

    func isLiked(_ garment: Garment) -> Bool {
        closet.contains { $0.id == garment.id }
    }

    /// True when every garment in the current outfit is already in the closet.
    var isCurrentOutfitLiked: Bool {
        guard let outfit = currentOutfit else { return false }
        return outfit.garments.allSatisfy(isLiked)
    }

    func like(_ garment: Garment) {
        guard !isLiked(garment) else { return }
        closet = closet + [garment]
    }

    func unlike(_ garment: Garment) {
        closet = closet.filter { $0.id != garment.id }
    }

    /// Saves every garment in the current outfit to the closet.
    func likeCurrentOutfit() {
        guard let outfit = currentOutfit else { return }
        closet = closet + outfit.garments.filter { !isLiked($0) }
    }

    /// Removes every garment in the current outfit from the closet.
    func unlikeCurrentOutfit() {
        guard let outfit = currentOutfit else { return }
        let ids = Set(outfit.garments.map(\.id))
        closet = closet.filter { !ids.contains($0.id) }
    }

    /// For a heart button: un-likes the outfit when it is fully liked, otherwise likes it.
    func toggleLikeCurrentOutfit() {
        if isCurrentOutfitLiked {
            unlikeCurrentOutfit()
        } else {
            likeCurrentOutfit()
        }
    }

    private static func withoutDuplicates(_ garments: [Garment]) -> [Garment] {
        var seen = Set<String>()
        return garments.filter { seen.insert($0.id).inserted }
    }
}
