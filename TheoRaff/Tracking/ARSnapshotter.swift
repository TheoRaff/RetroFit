import RealityKit
import UIKit

/// Takes a picture of the AR view: the camera image plus the 3D glasses,
/// without any of the SwiftUI controls drawn on top.
@MainActor
final class ARSnapshotter {
    weak var arView: ARView?

    func capture() async -> UIImage? {
        guard let arView else { return nil }
        return await withCheckedContinuation { continuation in
            arView.snapshot(saveToHDR: false) { image in
                continuation.resume(returning: image)
            }
        }
    }
}
