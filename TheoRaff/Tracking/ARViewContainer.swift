import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {
    let modelName: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        guard ARFaceTrackingConfiguration.isSupported else {
            print("Face tracking is not supported.")
            return arView
        }

        context.coordinator.arView = arView
        context.coordinator.setModel(modelName)

        arView.session.delegate = context.coordinator

        let configuration = ARFaceTrackingConfiguration()
        arView.session.run(configuration)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.setModel(modelName)
    }

    class Coordinator: NSObject, ARSessionDelegate {
        weak var arView: ARView?

        private var faceEntity: AnchorEntity?
        private var glassesEntity: Entity?
        private var glassesBaseWidth: Float = 0
        private var glassesBoundsCenter = SIMD3<Float>(repeating: 0)
        private var selectedModelName: String?

        func setModel(_ name: String) {
            guard selectedModelName != name else { return }
            selectedModelName = name

            if faceEntity != nil {
                loadSelectedModel()
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
                self.loadSelectedModel()
            }
        }

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            guard let faceAnchor = anchors.first(where: { $0 is ARFaceAnchor }) as? ARFaceAnchor else {
                return
            }

            DispatchQueue.main.async { [weak self] in
                self?.fitGlasses(to: faceAnchor)
            }
        }

        private func loadSelectedModel() {
            guard let selectedModelName, let faceEntity else {
                return
            }

            if let glassesEntity {
                faceEntity.removeChild(glassesEntity)
            }

            do {
                let glasses = try Entity.load(named: selectedModelName)
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
                print("Could not load glasses model \(selectedModelName): \(error)")
            }
        }

        private func fitGlasses(to faceAnchor: ARFaceAnchor) {
            guard let glassesEntity, glassesBaseWidth > 0 else {
                return
            }

            let left = faceAnchor.leftEyeTransform.columns.3
            let right = faceAnchor.rightEyeTransform.columns.3

            let leftEye = SIMD3<Float>(left.x, left.y, left.z)
            let rightEye = SIMD3<Float>(right.x, right.y, right.z)
            let eyeMidpoint = (leftEye + rightEye) / 2

            let targetWidth = simd_distance(leftEye, rightEye) * 2.2
            let scale = targetWidth / glassesBaseWidth

            glassesEntity.scale = SIMD3<Float>(repeating: scale)
            glassesEntity.position = SIMD3<Float>(
                eyeMidpoint.x - glassesBoundsCenter.x * scale,
                eyeMidpoint.y - glassesBoundsCenter.y * scale,
                eyeMidpoint.z - glassesBoundsCenter.z * scale + 0.02
            )
        }
    }
}
