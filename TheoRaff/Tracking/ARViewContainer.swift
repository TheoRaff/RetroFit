//
//  ARViewContainer.swift
//  TheoRaff
//
//  Created by Rafferty C on 24/10/2026.
//


import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {

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
        arView.session.delegate = context.coordinator

        let configuration = ARFaceTrackingConfiguration()
        arView.session.run(configuration)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    class Coordinator: NSObject, ARSessionDelegate {
        weak var arView: ARView?
        private var glassesEntity: ModelEntity?

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard let faceAnchor = anchors.first(where: {
                $0 is ARFaceAnchor
            }) as? ARFaceAnchor else {
                return
            }

            guard let arView = arView else { return }

            do {
                let loadedEntity = try Entity.load(
                    named: "Y2K_Sport_Sunglass"
                )

                // Adjust this after checking the first on-device result.
                loadedEntity.scale = SIMD3<Float>(repeating: 0.01)

                let faceEntity = AnchorEntity(anchor: faceAnchor)
                faceEntity.addChild(loadedEntity)

                DispatchQueue.main.async {
                    arView.scene.addAnchor(faceEntity)
                }

                glassesEntity = loadedEntity
            } catch {
                print("Could not load sunglasses: \(error)")
            }
        }
    }
}
