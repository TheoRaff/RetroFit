import Foundation
import RealityKit
import Testing
@testable import TheoRaff

/// Exercise the actual shipped USDZs through the same cache and bounds used by AR.
@MainActor
struct EyewearAssetTests {
    nonisolated static let models = ["Y2K_Ice_Blue_Rimless", "Y2K_Candy_Pink_Oval", "Y2K_Amber_Wrap", "Y2K_Violet_Butterfly"]

    @Test(arguments: models)
    func newEyewearLoadsAndFitsTheExistingEyePlacement(name: String) async throws {
        let library = FaceModelLibrary()
        let entity = try #require(await library.load(name))
        let copy = try #require(library.copy(of: name))
        #expect(entity !== copy)
        let bounds = entity.visualBounds(relativeTo: entity)
        #expect((0.14...0.17).contains(bounds.extents.x), "\(name) width: \(bounds.extents.x)")
        #expect((0.02...0.05).contains(bounds.extents.y), "\(name) height: \(bounds.extents.y)")
        #expect((0.13...0.17).contains(bounds.extents.z), "\(name) depth: \(bounds.extents.z)")
        #expect(abs(bounds.center.x) < 0.002)

        // Follow ARViewContainer's bounds-based fit at a typical 63 mm eye distance.
        let scale: Float = 0.063 * 2.2 / bounds.extents.x
        for side in ["Left", "Right"] {
            let lens = try #require(descendants(of: entity).first { $0.name.hasPrefix("\(side)_") && $0.name.contains("Lens") })
            let lensBounds = lens.visualBounds(relativeTo: entity)
            let centre = (lensBounds.center - bounds.center) * scale + SIMD3<Float>(0, 0, -0.035)
            #expect((0.015...0.05).contains(centre.z), "\(name) lens must sit in front of the eyes: \(centre)")
            #expect(abs(centre.y) < 0.008)
            #expect((0.025...0.038).contains(abs(centre.x)), "\(name) lens must line up with one eye: \(centre)")
        }
    }

    @Test func newEyewearIsAvailableInTheClosetAndLiveDeck() throws {
        let catalog = try Catalog.load()
        for name in Self.models {
            let garment = try #require(catalog.garments.first { $0.modelName == name })
            #expect(garment.category == .eyewear)
            #expect(catalog.liveLooks.contains { $0.garments == [garment] })
        }
    }

    /// The butterfly lenses use a packed texture rather than a flat tint.
    @Test func butterflyLensesLoadTheirEmbeddedGradient() async throws {
        let entity = try #require(await FaceModelLibrary().load("Y2K_Violet_Butterfly"))
        let lens = try #require(descendants(of: entity).first { $0.name.hasPrefix("Left_Violet_Lens") })
        let materials = ([lens] + descendants(of: lens))
            .flatMap { $0.components[ModelComponent.self]?.materials ?? [] }
            .compactMap { $0 as? PhysicallyBasedMaterial }
        #expect(materials.contains { $0.baseColor.texture != nil }, "The violet gradient must load from inside the USDZ")
    }

    private func descendants(of entity: Entity) -> [Entity] {
        entity.children.flatMap { [$0] + descendants(of: $0) }
    }
}
