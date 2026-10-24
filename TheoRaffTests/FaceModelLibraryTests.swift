import RealityKit
import Testing
@testable import TheoRaff

/// The AR view swaps glasses and hats through this cache, so a swipe never waits on a USDZ twice.
@MainActor
struct FaceModelLibraryTests {
    @Test func hasNothingUntilLoaded() {
        #expect(FaceModelLibrary().copy(of: "White_sunglasses") == nil)
    }

    @Test func loadsOnceThenHandsOutSeparateCopies() async throws {
        let library = FaceModelLibrary()
        let first = try #require(await library.load("White_sunglasses"))
        let second = try #require(library.copy(of: "White_sunglasses"))
        #expect(first !== second)
    }

    @Test func missingModelGivesNil() async {
        let library = FaceModelLibrary()
        #expect(await library.load("No_Such_Model") == nil)
        #expect(library.copy(of: "No_Such_Model") == nil)
    }
}
