import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {
    /// USDZ model to wear on the face, or nil to show no glasses.
    let modelName: String?
    /// Receives the AR view so the screen can take photos of it.
    var snapshotter: ARSnapshotter? = nil
    /// Called on the main thread with the glasses' frame in this view's coordinates as the
    /// face moves, or nil when there are no glasses or the face is lost.
    var onGlassesFrame: ((CGRect?) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        snapshotter?.arView = arView
        context.coordinator.onGlassesFrame = onGlassesFrame

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
        context.coordinator.onGlassesFrame = onGlassesFrame
        context.coordinator.setModel(modelName)
    }

    class Coordinator: NSObject, ARSessionDelegate {
        weak var arView: ARView?
        var onGlassesFrame: ((CGRect?) -> Void)?
        private var reportedGlassesFrame: CGRect?

        private var faceEntity: AnchorEntity?
        private var glassesEntity: Entity?
        private var glassesBaseWidth: Float = 0
        private var glassesBoundsCenter = SIMD3<Float>(repeating: 0)
        private var selectedModelName: String?

        func setModel(_ name: String?) {
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
            guard let faceEntity else {
                return
            }

            if let glassesEntity {
                faceEntity.removeChild(glassesEntity)
            }
            glassesEntity = nil
            glassesBaseWidth = 0
            reportGlassesFrame(nil)

            guard let selectedModelName else {
                return
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
                reportGlassesFrame(nil)
                return
            }
            defer { reportGlassesFrame(faceAnchor.isTracked ? screenFrame(of: glassesEntity) : nil) }

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
                eyeMidpoint.z - glassesBoundsCenter.z * scale - 0.035
            )
        }

        /// The box on screen around the entity's 3D bounds, or nil if any corner is behind the camera.
        /// The bounds are taken in the entity's own space and turned with it, so a tilted head
        /// doesn't swell the box the way a world-aligned box would.
        private func screenFrame(of entity: Entity) -> CGRect? {
            guard let arView else { return nil }
            let bounds = entity.visualBounds(relativeTo: entity)
            let (low, high) = (bounds.min, bounds.max)
            let corners = [low.x, high.x].flatMap { x in
                [low.y, high.y].flatMap { y in
                    [low.z, high.z].map { z in entity.convert(position: SIMD3<Float>(x, y, z), to: nil) }
                }
            }
            let points = corners.compactMap { arView.project($0) }
            guard points.count == corners.count,
                  let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
                  let minY = points.map(\.y).min(), let maxY = points.map(\.y).max() else {
                return nil
            }
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }

        /// Passes the frame on, skipping sub-point jitter so SwiftUI only redraws on real movement.
        private func reportGlassesFrame(_ frame: CGRect?) {
            let moved: Bool
            switch (frame, reportedGlassesFrame) {
            case (nil, nil):
                moved = false
            case let (new?, old?):
                moved = abs(new.minX - old.minX) >= 0.5 || abs(new.minY - old.minY) >= 0.5
                    || abs(new.width - old.width) >= 0.5 || abs(new.height - old.height) >= 0.5
            default:
                moved = true
            }
            guard moved else { return }
            reportedGlassesFrame = frame
            onGlassesFrame?(frame)
        }
    }
}
