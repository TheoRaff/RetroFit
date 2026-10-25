import Foundation
import RealityKit
import Testing
@testable import TheoRaff

/// The Y2K hair accessories and hoops ride in the hat slot: they're built around the reference
/// head with the origin between the eyes, then moved and scaled exactly like a hat. These load
/// the shipped USDZs and check each one sits where it's worn.
@MainActor
struct AccessoryAssetTests {
    typealias HatFit = ARViewContainer.HatFit

    nonisolated static let models = ["Y2K_Butterfly_Clips", "Y2K_Rhinestone_Tiara", "Y2K_Tinted_Visor", "Y2K_Bamboo_Hoops"]

    @Test(arguments: models)
    func loadsCentredBetweenTheEyes(name: String) async throws {
        let library = FaceModelLibrary()
        let entity = try #require(await library.load(name))
        let copy = try #require(library.copy(of: name))
        #expect(entity !== copy)
        let bounds = entity.visualBounds(relativeTo: entity)
        #expect((0.15...0.23).contains(bounds.extents.x), "\(name) is \(bounds.extents.x) m wide")
        #expect(abs(bounds.center.x) < 0.003, "\(name) isn't centred between the eyes")
    }

    /// The hat slot hides anything inside its head-shaped occluder, so no part may sink into it.
    @Test(arguments: models)
    func nothingIsBuriedInTheHeadOccluder(name: String) async throws {
        let entity = try #require(await FaceModelLibrary().load(name))
        let points = vertices(of: entity)
        #expect(points.count > 1_000)
        let buried = points.filter { simd_length_squared(($0 - HatFit.headCentre) / HatFit.headRadii) < 1 }
        #expect(buried.isEmpty, "\(name) has \(buried.count) vertices inside the head")
    }

    @Test func butterflyClipsLineTheFrontOfTheHair() async throws {
        let bounds = try await bounds(of: "Y2K_Butterfly_Clips")
        #expect(bounds.min.y > 0.03, "Clips must sit above the brows, not at \(bounds.min.y) m")
        #expect(bounds.max.y < 0.13)
        #expect(bounds.max.z < 0.01 && bounds.min.z > -0.06, "Clips belong at the front of the head")
    }

    @Test func tiaraCrownRisesAboveTheHead() async throws {
        let bounds = try await bounds(of: "Y2K_Rhinestone_Tiara")
        #expect((0.13...0.17).contains(bounds.max.y), "Crown top is at \(bounds.max.y) m")
        #expect(bounds.min.y > 0, "The band should end above the ears")
    }

    @Test func visorBrimSticksOutOverTheFace() async throws {
        let bounds = try await bounds(of: "Y2K_Tinted_Visor")
        #expect(bounds.max.z > 0.06, "Brim only reaches \(bounds.max.z) m forward")
        #expect(bounds.min.z < -0.15, "The band should go round the back of the head")
        #expect((0.06...0.09).contains(bounds.max.y), "Band top is at \(bounds.max.y) m")
        #expect(bounds.min.y > 0, "The brim should stay above the eyes")
    }

    /// +x is the wearer's left, as on ARKit's face anchor.
    @Test func hoopsHangFromBothEarlobes() async throws {
        let entity = try #require(await FaceModelLibrary().load("Y2K_Bamboo_Hoops"))
        for (side, sign) in [("Left", Float(1)), ("Right", Float(-1))] {
            let hoop = try #require(descendants(of: entity).first { $0.name.hasPrefix("\(side)_Hoop") })
            let bounds = hoop.visualBounds(relativeTo: entity)
            #expect((0.06...0.1).contains(bounds.center.x * sign), "\(side) hoop is at x \(bounds.center.x)")
            #expect((-0.045 ... -0.03).contains(bounds.max.y), "\(side) hoop top is at \(bounds.max.y) m")
            #expect(bounds.min.y > -0.11)
            #expect((-0.09 ... -0.05).contains(bounds.center.z), "\(side) hoop isn't level with the ear")
        }
    }

    /// The wings (one material per colour) and the visor brim are tinted see-through plastic.
    /// Blender's USD export drops alpha, so the opacity is written in afterwards and has to
    /// survive into RealityKit, which reads it into the base colour's alpha. Each see-through
    /// sheet is stored once per side, so it has to cull back faces, or both copies draw and
    /// the tint doubles.
    @Test(arguments: [("Y2K_Butterfly_Clips", 3), ("Y2K_Tinted_Visor", 1)])
    func translucentPartsStaySeeThrough(name: String, sheets: Int) async throws {
        let entity = try #require(await FaceModelLibrary().load(name))
        let seeThrough = ([entity] + descendants(of: entity))
            .flatMap { $0.components[ModelComponent.self]?.materials ?? [] }
            .compactMap { $0 as? PhysicallyBasedMaterial }
            .filter { material in
                guard case .transparent = material.blending else { return false }
                return material.baseColor.tint.cgColor.alpha < 1
            }
        #expect(seeThrough.count == sheets, "\(name) has \(seeThrough.count) see-through materials, not \(sheets)")
        #expect(seeThrough.allSatisfy { $0.faceCulling == .back }, "\(name) draws both sides of its see-through sheets")
    }

    @Test func accessoriesAreInTheClosetAndLiveDeck() throws {
        let catalog = try Catalog.load()
        for name in Self.models {
            let garment = try #require(catalog.garments.first { $0.modelName == name })
            #expect(garment.category == .headwear)
            #expect(catalog.liveLooks.contains { $0.garments == [garment] })
        }
    }

    private func bounds(of name: String) async throws -> BoundingBox {
        let entity = try #require(await FaceModelLibrary().load(name))
        return entity.visualBounds(relativeTo: entity)
    }

    /// Every vertex, in the model's own frame: the frame the hat slot puts on the wearer's eyes.
    private func vertices(of entity: Entity) -> [SIMD3<Float>] {
        ([entity] + descendants(of: entity)).flatMap { part -> [SIMD3<Float>] in
            guard let mesh = part.components[ModelComponent.self]?.mesh else { return [] }
            let toModel = part.transformMatrix(relativeTo: entity)
            let contents = mesh.contents
            return contents.instances.flatMap { instance -> [SIMD3<Float>] in
                guard let model = contents.models[instance.model] else { return [] }
                let transform = toModel * instance.transform
                return model.parts.flatMap(\.positions.elements).map { point in
                    let moved = transform * SIMD4<Float>(point, 1)
                    return SIMD3<Float>(moved.x, moved.y, moved.z)
                }
            }
        }
    }

    private func descendants(of entity: Entity) -> [Entity] {
        entity.children.flatMap { [$0] + descendants(of: $0) }
    }
}
