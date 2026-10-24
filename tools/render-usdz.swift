// Renders a USDZ model from the front on a transparent background, as a product photo
// for face items (eyewear, headwear) that only exist as 3D models:
//
//   xcrun swift tools/render-usdz.swift TheoRaff/Resources/White_sunglasses.usdz /tmp/white.png [yawDegrees]
//   xcrun swift tools/prep-garment.swift /tmp/white.png white-shades --keep-background
//
// The camera looks down -z with an orthographic lens. Pass a yaw in degrees if the model
// faces another way.

import AppKit
import ImageIO
import SceneKit

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    FileHandle.standardError.write(Data("Usage: xcrun swift tools/render-usdz.swift <model.usdz> <out.png> [yawDegrees]\n".utf8))
    exit(1)
}
let modelURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])
let yaw = arguments.count > 3 ? (Double(arguments[3]) ?? 0) * .pi / 180 : 0

let scene: SCNScene
do {
    scene = try SCNScene(url: modelURL, options: nil)
} catch {
    FileHandle.standardError.write(Data("render-usdz: can't open \(modelURL.path): \(error)\n".utf8))
    exit(1)
}
let holder = SCNNode()
scene.rootNode.childNodes.forEach { holder.addChildNode($0) }
holder.eulerAngles.y = CGFloat(yaw)
scene.rootNode.addChildNode(holder)

let (low, high) = holder.boundingBox
let lowWorld = holder.convertPosition(low, to: nil)
let highWorld = holder.convertPosition(high, to: nil)
let center = SCNVector3((lowWorld.x + highWorld.x) / 2, (lowWorld.y + highWorld.y) / 2, (lowWorld.z + highWorld.z) / 2)
let width = abs(highWorld.x - lowWorld.x)
let height = abs(highWorld.y - lowWorld.y)
let depth = abs(highWorld.z - lowWorld.z)

let camera = SCNCamera()
camera.usesOrthographicProjection = true
camera.orthographicScale = Double(max(width, height)) * 0.6
camera.zFar = Double(depth * 20 + 10)
let cameraNode = SCNNode()
cameraNode.camera = camera
cameraNode.position = SCNVector3(center.x, center.y, center.z + depth * 5 + 1)
scene.rootNode.addChildNode(cameraNode)
scene.background.contents = NSColor.clear

let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
renderer.scene = scene
renderer.pointOfView = cameraNode
renderer.autoenablesDefaultLighting = true
let image = renderer.snapshot(atTime: 0, with: CGSize(width: 1200, height: 1200), antialiasingMode: .multisampling4X)
guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, "public.png" as CFString, 1, nil) else {
    FileHandle.standardError.write(Data("render-usdz: couldn't render \(modelURL.path)\n".utf8))
    exit(1)
}
CGImageDestinationAddImage(destination, cgImage, nil)
guard CGImageDestinationFinalize(destination) else {
    FileHandle.standardError.write(Data("render-usdz: couldn't save \(outputURL.path)\n".utf8))
    exit(1)
}
print("Saved \(outputURL.path)")
