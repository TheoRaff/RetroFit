import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {
    /// USDZ model to wear over the eyes, or nil to show no glasses.
    let glassesModel: String?
    /// USDZ model to wear on the head, or nil to show no hat.
    var hatModel: String? = nil
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
        context.coordinator.setModels(glasses: glassesModel, hat: hatModel)

        arView.session.delegate = context.coordinator

        let configuration = ARFaceTrackingConfiguration()
        arView.session.run(configuration)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.setModels(glasses: glassesModel, hat: hatModel)
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

    class Coordinator: NSObject, ARSessionDelegate {
        weak var arView: ARView?

        private var faceEntity: AnchorEntity?
        private var glassesEntity: Entity?
        private var glassesBaseWidth: Float = 0
        private var glassesBoundsCenter = SIMD3<Float>(repeating: 0)
        private var hatEntity: Entity?
        private var selectedGlasses: String?
        private var selectedHat: String?

        func setModels(glasses: String?, hat: String?) {
            if selectedGlasses != glasses {
                selectedGlasses = glasses
                if faceEntity != nil { loadGlasses() }
            }
            if selectedHat != hat {
                selectedHat = hat
                if faceEntity != nil { loadHat() }
            }
        }

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard
                faceEntity == nil,
                let faceAnchor = anchors.first(where: { $0 is ARFaceAnchor }) as? ARFaceAnchor
            else {
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard let self, let arView = self.arView else { return }

                let newFaceEntity = AnchorEntity(anchor: faceAnchor)
                self.faceEntity = newFaceEntity
                arView.scene.addAnchor(newFaceEntity)
                self.loadGlasses()
                self.loadHat()
            }
        }

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            guard let faceAnchor = anchors.first(where: { $0 is ARFaceAnchor }) as? ARFaceAnchor else {
                return
            }

            DispatchQueue.main.async { [weak self] in
                self?.fitGlasses(to: faceAnchor)
                self?.fitHat(to: faceAnchor)
            }
        }

        private func loadGlasses() {
            guard let faceEntity else {
                return
            }

            if let glassesEntity {
                faceEntity.removeChild(glassesEntity)
            }
            glassesEntity = nil
            glassesBaseWidth = 0

            guard let selectedGlasses else {
                return
            }

            do {
                let glasses = try Entity.load(named: selectedGlasses)
                let bounds = glasses.visualBounds(relativeTo: glasses)

                guard bounds.extents.x > 0 else {
                    print("Could not determine the glasses model width.")
                    return
                }

                glassesBaseWidth = bounds.extents.x
                glassesBoundsCenter = bounds.center

                faceEntity.addChild(glasses)
                glassesEntity = glasses
            } catch {
                print("Could not load glasses model \(selectedGlasses): \(error)")
            }
        }

        private func loadHat() {
            guard let faceEntity else {
                return
            }

            if let hatEntity {
                faceEntity.removeChild(hatEntity)
            }
            hatEntity = nil

            guard let selectedHat else {
                return
            }

            do {
                let hat = try Entity.load(named: selectedHat)
                let head = ModelEntity(mesh: .generateSphere(radius: 1), materials: [OcclusionMaterial()])
                head.position = HatFit.headCentre
                head.scale = HatFit.headRadii

                // Hidden until the first face update puts it on the head.
                let holder = Entity()
                holder.isEnabled = false
                holder.addChild(hat)
                holder.addChild(head)
                faceEntity.addChild(holder)
                hatEntity = holder
            } catch {
                print("Could not load hat model \(selectedHat): \(error)")
            }
        }

        private func eyePositions(of faceAnchor: ARFaceAnchor) -> (left: SIMD3<Float>, right: SIMD3<Float>) {
            let left = faceAnchor.leftEyeTransform.columns.3
            let right = faceAnchor.rightEyeTransform.columns.3
            return (SIMD3<Float>(left.x, left.y, left.z), SIMD3<Float>(right.x, right.y, right.z))
        }

        private func fitGlasses(to faceAnchor: ARFaceAnchor) {
            guard let glassesEntity, glassesBaseWidth > 0 else {
                return
            }

            let (leftEye, rightEye) = eyePositions(of: faceAnchor)
            let eyeMidpoint = (leftEye + rightEye) / 2

            let targetWidth = simd_distance(leftEye, rightEye) * 2.2
            let scale = targetWidth / glassesBaseWidth

            glassesEntity.scale = SIMD3<Float>(repeating: scale)
            glassesEntity.position = SIMD3<Float>(
                eyeMidpoint.x - glassesBoundsCenter.x * scale,
                eyeMidpoint.y - glassesBoundsCenter.y * scale,
                eyeMidpoint.z - glassesBoundsCenter.z * scale - 0.035
            )
        }

        private func fitHat(to faceAnchor: ARFaceAnchor) {
            guard let hatEntity else {
                return
            }

            let (leftEye, rightEye) = eyePositions(of: faceAnchor)
            hatEntity.scale = SIMD3<Float>(repeating: HatFit.scale(eyeDistance: simd_distance(leftEye, rightEye)))
            hatEntity.position = (leftEye + rightEye) / 2
            hatEntity.isEnabled = true
        }
    }
}
