import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {
    /// USDZ model to wear over the eyes, or nil to show no glasses.
    let glassesModel: String?
    /// USDZ model to wear on the head, or nil to show no hat.
    var hatModel: String? = nil
    /// Models to load in the background up front, so swiping to them is instant.
    var preloadModels: [String] = []
    /// Receives the AR view so the screen can take photos of it.
    var snapshotter: ARSnapshotter? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        snapshotter?.arView = arView

        guard ARFaceTrackingConfiguration.isSupported else {
            print("Face tracking is not supported.")
            return arView
        }

        context.coordinator.arView = arView
        context.coordinator.library.preload(preloadModels)
        context.coordinator.wear(glasses: glassesModel, hat: hatModel)

        arView.session.delegate = context.coordinator

        let configuration = ARFaceTrackingConfiguration()
        arView.session.run(configuration)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.wear(glasses: glassesModel, hat: hatModel)
    }

    /// Hat models are built around a reference head in metres, with the origin halfway
    /// between the eyes, +y up and +z out of the face. They only need moving to the
    /// wearer's eyes and scaling to the size of their head.
    enum HatFit {
        /// Distance between the eyes on the reference head.
        static let referenceEyeDistance: Float = 0.063
        /// Keeps a bad eye reading from shrinking or ballooning the hat.
        static let scaleRange: ClosedRange<Float> = 0.85...1.2
        /// The reference head as an ellipsoid, slightly inside the hats so it hides the
        /// parts behind the wearer's head (the far side of the brim and the inside).
        static let headCentre = SIMD3<Float>(0, 0.015, -0.085)
        static let headRadii = SIMD3<Float>(0.075, 0.099, 0.094)

        static func scale(eyeDistance: Float) -> Float {
            min(max(eyeDistance / referenceEyeDistance, scaleRange.lowerBound), scaleRange.upperBound)
        }
    }

    /// Keeps the worn models in step with the card. A swipe takes the old model off at once,
    /// and a model that finishes loading after the look has changed again is thrown away.
    @MainActor
    final class Coordinator: NSObject, ARSessionDelegate {
        weak var arView: ARView?
        let library = FaceModelLibrary()

        private enum Slot: CaseIterable {
            case glasses, hat
        }

        /// What one slot should show, and what it shows now.
        private struct Worn {
            var name: String?
            var entity: Entity?
            /// Glasses only: the model's own width and centre, for fitting it to the eyes.
            var baseWidth: Float = 0
            var boundsCenter = SIMD3<Float>(repeating: 0)
        }

        private var worn: [Slot: Worn] = [.glasses: Worn(), .hat: Worn()]
        private var faceEntity: AnchorEntity?
        private var faceAnchorID: UUID?

        func wear(glasses: String?, hat: String?) {
            change(.glasses, to: glasses)
            change(.hat, to: hat)
        }

        // MARK: Face anchor

        nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard let faceAnchor = anchors.lazy.compactMap({ $0 as? ARFaceAnchor }).first else { return }
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated { self?.attachFace(faceAnchor) }
            }
        }

        nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            let removed = Set(anchors.map(\.identifier))
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, let id = self.faceAnchorID, removed.contains(id) else { return }
                    self.detachFace()
                }
            }
        }

        nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            guard let faceAnchor = anchors.lazy.compactMap({ $0 as? ARFaceAnchor }).first else { return }
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, faceAnchor.identifier == self.faceAnchorID else { return }
                    self.fitGlasses(to: faceAnchor)
                    self.fitHat(to: faceAnchor)
                }
            }
        }

        /// ARKit can drop the face and add a new anchor. Move everything over to the new one.
        private func attachFace(_ faceAnchor: ARFaceAnchor) {
            guard faceAnchor.identifier != faceAnchorID, let arView else { return }
            detachFace()
            let entity = AnchorEntity(anchor: faceAnchor)
            arView.scene.addAnchor(entity)
            faceEntity = entity
            faceAnchorID = faceAnchor.identifier
            Slot.allCases.forEach(putOn)
        }

        private func detachFace() {
            Slot.allCases.forEach(takeOff)
            if let faceEntity {
                arView?.scene.removeAnchor(faceEntity)
            }
            faceEntity = nil
            faceAnchorID = nil
        }

        // MARK: Putting models on

        private func change(_ slot: Slot, to name: String?) {
            guard worn[slot]?.name != name else { return }
            takeOff(slot)
            worn[slot]?.name = name
            putOn(slot)
        }

        private func takeOff(_ slot: Slot) {
            worn[slot]?.entity?.removeFromParent()
            worn[slot]?.entity = nil
            worn[slot]?.baseWidth = 0
        }

        private func putOn(_ slot: Slot) {
            guard faceEntity != nil, let name = worn[slot]?.name, worn[slot]?.entity == nil else { return }
            if let model = library.copy(of: name) {
                attach(model, named: name, to: slot)
                return
            }
            Task {
                guard let model = await library.load(name) else { return }
                attach(model, named: name, to: slot)
            }
        }

        /// Adds the model, unless the look moved on or the face was lost while it loaded.
        private func attach(_ model: Entity, named name: String, to slot: Slot) {
            guard let faceEntity, worn[slot]?.name == name, worn[slot]?.entity == nil else { return }

            switch slot {
            case .glasses:
                let bounds = model.visualBounds(relativeTo: model)
                guard bounds.extents.x > 0 else {
                    print("Could not determine the glasses model width.")
                    return
                }
                worn[slot]?.baseWidth = bounds.extents.x
                worn[slot]?.boundsCenter = bounds.center
                faceEntity.addChild(model)
                worn[slot]?.entity = model
            case .hat:
                let head = ModelEntity(mesh: .generateSphere(radius: 1), materials: [OcclusionMaterial()])
                head.position = HatFit.headCentre
                head.scale = HatFit.headRadii

                // Hidden until the next face update puts it on the head.
                let holder = Entity()
                holder.isEnabled = false
                holder.addChild(model)
                holder.addChild(head)
                faceEntity.addChild(holder)
                worn[slot]?.entity = holder
            }
        }

        // MARK: Fitting

        private func eyePositions(of faceAnchor: ARFaceAnchor) -> (left: SIMD3<Float>, right: SIMD3<Float>) {
            let left = faceAnchor.leftEyeTransform.columns.3
            let right = faceAnchor.rightEyeTransform.columns.3
            return (SIMD3<Float>(left.x, left.y, left.z), SIMD3<Float>(right.x, right.y, right.z))
        }

        private func fitGlasses(to faceAnchor: ARFaceAnchor) {
            guard let glasses = worn[.glasses], let entity = glasses.entity, glasses.baseWidth > 0 else {
                return
            }

            let (leftEye, rightEye) = eyePositions(of: faceAnchor)
            let eyeMidpoint = (leftEye + rightEye) / 2

            let targetWidth = simd_distance(leftEye, rightEye) * 2.2
            let scale = targetWidth / glasses.baseWidth

            entity.scale = SIMD3<Float>(repeating: scale)
            entity.position = SIMD3<Float>(
                eyeMidpoint.x - glasses.boundsCenter.x * scale,
                eyeMidpoint.y - glasses.boundsCenter.y * scale,
                eyeMidpoint.z - glasses.boundsCenter.z * scale - 0.035
                    + (glasses.name == "Y2K_glasses" ? 0.02 : 0)
            )
        }

        private func fitHat(to faceAnchor: ARFaceAnchor) {
            guard let entity = worn[.hat]?.entity else {
                return
            }

            let (leftEye, rightEye) = eyePositions(of: faceAnchor)
            entity.scale = SIMD3<Float>(repeating: HatFit.scale(eyeDistance: simd_distance(leftEye, rightEye)))
            entity.position = (leftEye + rightEye) / 2
            entity.isEnabled = true
        }
    }
}
