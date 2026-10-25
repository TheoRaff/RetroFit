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

    /// The lenses are tinted see-through plastic. Blender's USD export drops alpha, so the
    /// opacity is written in afterwards and has to survive into RealityKit, which reads it into
    /// the base colour's alpha.
    @Test(arguments: models)
    func lensesStaySeeThrough(name: String) async throws {
        let entity = try #require(await FaceModelLibrary().load(name))
        let materials = descendants(of: entity)
            .filter { $0.name.contains("Lens") }
            .flatMap { $0.components[ModelComponent.self]?.materials ?? [] }
        #expect(materials.count == 2, "\(name) has \(materials.count) lens materials, not one per lens")
        for material in materials {
            let lens = try #require(material as? PhysicallyBasedMaterial, "\(name) lens isn't physically based")
            guard case .transparent = lens.blending else {
                Issue.record("\(name) lens is opaque")
                continue
            }
            let alpha = lens.baseColor.tint.cgColor.alpha
            #expect((0.5..<1).contains(alpha), "\(name) lens alpha \(alpha) isn't a see-through tint")
        }
    }

    /// RealityKit culls the back faces of every USD material, so each see-through lens is one
    /// sheet stored once facing out and once facing the eyes: only one copy draws from any angle.
    /// A closed thin shell would draw its front and back layers over each other in streaks.
    @Test(arguments: models)
    func lensesAreTwoWaySheets(name: String) async throws {
        let entity = try #require(await FaceModelLibrary().load(name))
        let lenses = descendants(of: entity).filter { $0.name.contains("Lens") && $0.components.has(ModelComponent.self) }
        #expect(lenses.count == 2)
        for lens in lenses {
            let triangles = triangles(of: lens)
            let drawn = Set(triangles.map(canonical))
            let unpaired = triangles.filter { !drawn.contains(canonical([$0[0], $0[2], $0[1]])) }
            #expect(!triangles.isEmpty && unpaired.isEmpty, "\(lens.name): \(unpaired.count) of \(triangles.count) triangles have no copy facing the other way")
        }
    }

    /// The entity's triangles as wound, with corners rounded to the micrometre.
    private func triangles(of entity: Entity) -> [[SIMD3<Int32>]] {
        guard let contents = entity.components[ModelComponent.self]?.mesh.contents else { return [] }
        return contents.models.flatMap { model in
            model.parts.flatMap { part -> [[SIMD3<Int32>]] in
                let positions = part.positions.elements
                let indices = part.triangleIndices?.elements ?? []
                return stride(from: 0, to: indices.count - 2, by: 3).map { start in
                    (0..<3).map { SIMD3<Int32>(positions[Int(indices[start + $0])] * 1_000_000, rounding: .toNearestOrEven) }
                }
            }
        }
    }

    /// The same triangle starts at the same corner whichever corner it was listed from.
    private func canonical(_ triangle: [SIMD3<Int32>]) -> [SIMD3<Int32>] {
        let first = triangle.indices.min { [triangle[$0].x, triangle[$0].y, triangle[$0].z].lexicographicallyPrecedes([triangle[$1].x, triangle[$1].y, triangle[$1].z]) }!
        return (0..<3).map { triangle[(first + $0) % 3] }
    }

    private func descendants(of entity: Entity) -> [Entity] {
        entity.children.flatMap { [$0] + descendants(of: $0) }
    }
}
