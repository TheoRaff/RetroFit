import Testing
@testable import TheoRaff

@MainActor
struct TryOnSessionTests {
    private func makeSession(outfitCount: Int = 3) throws -> TryOnSession {
        let outfits = try (1...outfitCount).map { try Fixtures.outfit(id: "look-\($0)") }
        return TryOnSession(outfits: outfits)
    }

    // MARK: Moving between outfits

    @Test func startsOnTheFirstOutfit() throws {
        let session = try makeSession()
        #expect(session.currentIndex == 0)
        #expect(session.currentOutfit?.id == "look-1")
        #expect(session.canShowPrevious == false)
        #expect(session.canShowNext)
    }

    @Test func emptySessionHasNothingToShow() {
        let session = TryOnSession()
        #expect(session.currentOutfit == nil)
        #expect(session.canShowNext == false)
        #expect(session.canShowPrevious == false)
        session.showNext()
        session.showPrevious()
        #expect(session.currentIndex == 0)
    }

    @Test func showNextMovesForward() throws {
        let session = try makeSession()
        session.showNext()
        #expect(session.currentOutfit?.id == "look-2")
        #expect(session.canShowPrevious)
    }

    @Test func showNextStopsAtTheLastOutfit() throws {
        let session = try makeSession(outfitCount: 2)
        session.showNext()
        session.showNext()
        #expect(session.currentOutfit?.id == "look-2")
        #expect(session.canShowNext == false)
    }

    @Test func showPreviousGoesBack() throws {
        let session = try makeSession()
        session.showNext()
        session.showNext()
        session.showPrevious()
        #expect(session.currentOutfit?.id == "look-2")
    }

    @Test func showPreviousStopsAtTheFirstOutfit() throws {
        let session = try makeSession()
        session.showPrevious()
        #expect(session.currentOutfit?.id == "look-1")
    }

    @Test func replacingOutfitsGoesBackToTheStart() throws {
        let session = try makeSession()
        session.showNext()
        let fresh = [try Fixtures.outfit(id: "new-1"), try Fixtures.outfit(id: "new-2")]
        session.replaceOutfits(fresh)
        #expect(session.currentIndex == 0)
        #expect(session.currentOutfit?.id == "new-1")
    }

    @Test func movingDoesNotTouchTheCloset() throws {
        let session = try makeSession()
        session.likeCurrentOutfit()
        session.showNext()
        session.showPrevious()
        #expect(session.closet.count == 1)
    }

    // MARK: Liking

    @Test func likeSavesAGarmentToTheCloset() throws {
        let session = try makeSession()
        let hoodie = try Fixtures.garment(id: "hoodie")
        session.like(hoodie)
        #expect(session.closet == [hoodie])
        #expect(session.isLiked(hoodie))
    }

    @Test func likingTwiceKeepsOneCopy() throws {
        let session = try makeSession()
        let hoodie = try Fixtures.garment(id: "hoodie")
        session.like(hoodie)
        session.like(hoodie)
        #expect(session.closet.count == 1)
    }

    @Test func likeCurrentOutfitSavesEveryGarmentInIt() throws {
        let shades = try Fixtures.garment(id: "shades", category: .eyewear)
        let hoodie = try Fixtures.garment(id: "hoodie", category: .top)
        let look = try Fixtures.outfit(id: "look", garments: [shades, hoodie])
        let session = TryOnSession(outfits: [look])
        session.likeCurrentOutfit()
        #expect(session.closet == [shades, hoodie])
        #expect(session.isCurrentOutfitLiked)
    }

    @Test func likeCurrentOutfitWithNoOutfitsDoesNothing() {
        let session = TryOnSession()
        session.likeCurrentOutfit()
        #expect(session.closet.isEmpty)
        #expect(session.isCurrentOutfitLiked == false)
    }

    @Test func outfitIsOnlyLikedWhenEveryGarmentIs() throws {
        let shades = try Fixtures.garment(id: "shades", category: .eyewear)
        let hoodie = try Fixtures.garment(id: "hoodie", category: .top)
        let session = TryOnSession(outfits: [try Fixtures.outfit(id: "look", garments: [shades, hoodie])])
        session.like(shades)
        #expect(session.isCurrentOutfitLiked == false)
    }

    @Test func unlikeRemovesTheGarment() throws {
        let session = try makeSession()
        let hoodie = try Fixtures.garment(id: "hoodie")
        let tee = try Fixtures.garment(id: "tee")
        session.like(hoodie)
        session.like(tee)
        session.unlike(hoodie)
        #expect(session.closet == [tee])
        #expect(session.isLiked(hoodie) == false)
    }

    @Test func startingClosetDropsDuplicates() throws {
        let hoodie = try Fixtures.garment(id: "hoodie")
        let session = TryOnSession(outfits: [], closet: [hoodie, hoodie])
        #expect(session.closet == [hoodie])
    }

    // MARK: Return values, jumping and toggling

    @Test func movingReportsWhetherItMoved() throws {
        let session = try makeSession(outfitCount: 2)
        #expect(session.showPrevious() == false)
        #expect(session.showNext())
        #expect(session.showNext() == false)
        #expect(session.showPrevious())
    }

    @Test func showOutfitIDJumpsStraightThere() throws {
        let session = try makeSession()
        #expect(session.show(outfitID: "look-3"))
        #expect(session.currentIndex == 2)
    }

    @Test func showUnknownOutfitIDStaysPut() throws {
        let session = try makeSession()
        session.showNext()
        #expect(session.show(outfitID: "missing") == false)
        #expect(session.currentOutfit?.id == "look-2")
    }

    @Test func unlikeCurrentOutfitRemovesOnlyItsGarments() throws {
        let session = try makeSession()
        let other = try Fixtures.garment(id: "other")
        session.like(other)
        session.likeCurrentOutfit()
        session.unlikeCurrentOutfit()
        #expect(session.closet == [other])
    }

    @Test func toggleLikeLikesThenUnlikes() throws {
        let session = try makeSession()
        session.toggleLikeCurrentOutfit()
        #expect(session.isCurrentOutfitLiked)
        session.toggleLikeCurrentOutfit()
        #expect(session.isCurrentOutfitLiked == false)
        #expect(session.closet.isEmpty)
    }

    @Test func unlikeCurrentOutfitWithNoOutfitsDoesNothing() throws {
        let hoodie = try Fixtures.garment(id: "hoodie")
        let session = TryOnSession(closet: [hoodie])
        session.unlikeCurrentOutfit()
        #expect(session.closet == [hoodie])
    }
}

