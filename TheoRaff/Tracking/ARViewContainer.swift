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
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.session.run(ARFaceTrackingConfiguration())
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
