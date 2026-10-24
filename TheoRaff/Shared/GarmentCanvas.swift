import CoreGraphics

/// The canvas every garment photo is drawn on by `tools/prep-garment.swift`, in pixels
/// from the top-left. Tops are placed so their shoulder seams land on `leftShoulder` and
/// `rightShoulder`, so a body overlay can pin those two points to the wearer's shoulders.
/// Everything else is centred.
enum GarmentCanvas {
    static let size = CGSize(width: 768, height: 960)
    static let leftShoulder = CGPoint(x: 234, y: 320)
    static let rightShoulder = CGPoint(x: 534, y: 320)
}
