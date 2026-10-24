// Cuts a garment photo out of its background, lays it on the shared garment canvas
// and saves it into the app's asset catalog as <garment-id>.imageset.
//
//   xcrun swift tools/prep-garment.swift <photo> <garment-id> [options]
//
//   --top                    Place the garment by its shoulder seams (tops). Others are centred.
//   --shoulders LX,LY,RX,RY  Shoulder seam pixels in the photo: left x,y then right x,y, measured
//                            from the top-left as Preview shows them. Needs --top. Guessed if left out.
//   --keep-background        The photo is already a transparent cutout. Skips background removal.
//   --clear-above Y          Erases everything above pixel row Y, such as a hanger hook.
//   --grid <png>             Also writes the cutout with a 100 px grid, for reading off shoulder pixels.
//   --preview <png>          Also writes the canvas with the shoulder targets marked.
//   --force                  Saves even when the garment runs off the canvas, cropping it.
//   --assets <dir>           Asset catalog to write into. Default: TheoRaff/Resources/Assets.xcassets
//
// Every canvas is 768 x 960 px. Tops have the left shoulder seam at (234, 320) and the
// right one at (534, 320), so a body overlay can pin those two points to the wearer's shoulders.

import AppKit
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

enum Canvas {
    static let width = 768
    static let height = 960
    static let leftShoulder = CGPoint(x: 234, y: 320)
    static let rightShoulder = CGPoint(x: 534, y: 320)
    /// Space left around garments that are centred rather than placed by the shoulders.
    static let margin: CGFloat = 0.06
}

struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

struct Options {
    var photo: URL
    var garmentID: String
    var isTop = false
    var shoulders: (left: CGPoint, right: CGPoint)?
    var keepBackground = false
    var clearAbove: Int?
    var gridURL: URL?
    var previewURL: URL?
    var force = false
    var assets = URL(fileURLWithPath: "TheoRaff/Resources/Assets.xcassets")

    init(arguments: [String]) throws {
        guard arguments.count >= 2, !arguments[0].hasPrefix("--"), !arguments[1].hasPrefix("--") else {
            throw Failure("Usage: xcrun swift tools/prep-garment.swift <photo> <garment-id> [--top] [--shoulders LX,LY,RX,RY] [--keep-background] [--clear-above Y] [--grid out.png] [--preview out.png] [--force] [--assets dir]")
        }
        photo = URL(fileURLWithPath: arguments[0])
        garmentID = arguments[1]
        guard garmentID.range(of: "^[a-z0-9]+(-[a-z0-9]+)*$", options: .regularExpression) != nil else {
            throw Failure("Garment id must be lowercase words joined by hyphens, like pink-velour-hoodie")
        }
        var index = 2
        func value(for flag: String) throws -> String {
            index += 1
            guard index < arguments.count else { throw Failure("\(flag) needs a value") }
            return arguments[index]
        }
        while index < arguments.count {
            let flag = arguments[index]
            switch flag {
            case "--top": isTop = true
            case "--keep-background": keepBackground = true
            case "--clear-above":
                guard let y = Int(try value(for: flag)), y > 0 else { throw Failure("--clear-above takes a pixel row, like 120") }
                clearAbove = y
            case "--shoulders": shoulders = try Self.parseShoulders(value(for: flag))
            case "--grid": gridURL = URL(fileURLWithPath: try value(for: flag))
            case "--preview": previewURL = URL(fileURLWithPath: try value(for: flag))
            case "--force": force = true
            case "--assets": assets = URL(fileURLWithPath: try value(for: flag))
            default: throw Failure("Unknown option \(flag)")
            }
            index += 1
        }
        if shoulders != nil && !isTop {
            throw Failure("--shoulders only places tops. Add --top, or drop --shoulders to centre the garment.")
        }
    }

    private static func parseShoulders(_ text: String) throws -> (left: CGPoint, right: CGPoint) {
        let numbers = text.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard numbers.count == 4, numbers.allSatisfy(\.isFinite) else {
            throw Failure("--shoulders takes four numbers: leftX,leftY,rightX,rightY")
        }
        let left = CGPoint(x: numbers[0], y: numbers[1])
        let right = CGPoint(x: numbers[2], y: numbers[3])
        guard right.x > left.x else { throw Failure("The right shoulder must be to the right of the left one") }
        return (left, right)
    }
}

// MARK: Loading and cutting out

/// Loads the photo the right way up, at full size.
func loadImage(_ url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int else {
        throw Failure("Can't read an image from \(url.path)")
    }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: max(width, height),
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
        throw Failure("Can't decode \(url.path)")
    }
    return image
}

/// Keeps the photo's foreground objects and makes everything else transparent.
func removeBackground(_ image: CGImage) throws -> CGImage {
    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(cgImage: image)
    try handler.perform([request])
    guard let result = request.results?.first, !result.allInstances.isEmpty else {
        throw Failure("Couldn't find the garment in the photo. Try one on a plain background.")
    }
    let buffer = try result.generateMaskedImage(ofInstances: result.allInstances, from: handler, croppedToInstancesExtent: false)
    let masked = CIImage(cvPixelBuffer: buffer)
    guard let output = CIContext().createCGImage(masked, from: masked.extent) else {
        throw Failure("Couldn't render the cutout")
    }
    return output
}

/// Makes the rows above `row` transparent.
func clearing(_ image: CGImage, above row: Int) throws -> CGImage {
    let context = try makeContext(width: image.width, height: image.height)
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    // Core Graphics counts rows from the bottom.
    context.clear(CGRect(x: 0, y: image.height - row, width: image.width, height: row))
    guard let output = context.makeImage() else { throw Failure("Couldn't clear the top of the cutout") }
    return output
}

// MARK: Measuring

/// The image's alpha channel, row 0 at the top.
struct AlphaMap {
    let width: Int
    let height: Int
    private let alpha: [UInt8]
    private static let opaque: UInt8 = 24

    init(_ image: CGImage) throws {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { throw Failure("Couldn't read the cutout's pixels") }
        self.width = width
        self.height = height
        alpha = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
    }

    /// Leftmost and rightmost solid pixel in a row.
    func extent(ofRow y: Int) -> (minX: Int, maxX: Int)? {
        let row = alpha[(y * width)..<((y + 1) * width)]
        guard let first = row.firstIndex(where: { $0 >= Self.opaque }),
              let last = row.lastIndex(where: { $0 >= Self.opaque }) else { return nil }
        return (first - y * width, last - y * width)
    }

    /// The smallest rectangle holding every solid pixel, in top-left coordinates.
    var solidBounds: CGRect? {
        let rows = (0..<height).compactMap { y in extent(ofRow: y).map { (y, $0) } }
        guard let top = rows.first?.0, let bottom = rows.last?.0 else { return nil }
        let minX = rows.map(\.1.minX).min() ?? 0
        let maxX = rows.map(\.1.maxX).max() ?? 0
        return CGRect(x: minX, y: top, width: maxX - minX + 1, height: bottom - top + 1)
    }

    /// A rough guess at a top's shoulder seams: the garment's outline a little below its top edge.
    /// Wrong for hoods and odd shapes, so check the preview.
    func guessShoulders(in bounds: CGRect) -> (left: CGPoint, right: CGPoint)? {
        let y = Int(bounds.minY + bounds.height * 0.10)
        guard let row = extent(ofRow: y) else { return nil }
        return (CGPoint(x: row.minX, y: y), CGPoint(x: row.maxX, y: y))
    }
}

// MARK: Placing on the canvas

/// Maps photo pixels to canvas pixels, both measured from the top-left.
func placement(for bounds: CGRect, shoulders: (left: CGPoint, right: CGPoint)?) -> CGAffineTransform {
    let canvasWidth = CGFloat(Canvas.width)
    let canvasHeight = CGFloat(Canvas.height)
    if let shoulders {
        let source = CGPoint(x: shoulders.right.x - shoulders.left.x, y: shoulders.right.y - shoulders.left.y)
        let target = CGPoint(x: Canvas.rightShoulder.x - Canvas.leftShoulder.x, y: Canvas.rightShoulder.y - Canvas.leftShoulder.y)
        let scale = hypot(target.x, target.y) / hypot(source.x, source.y)
        let angle = atan2(target.y, target.x) - atan2(source.y, source.x)
        return CGAffineTransform(translationX: -shoulders.left.x, y: -shoulders.left.y)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(rotationAngle: angle))
            .concatenating(CGAffineTransform(translationX: Canvas.leftShoulder.x, y: Canvas.leftShoulder.y))
    }
    let usableWidth = canvasWidth * (1 - 2 * Canvas.margin)
    let usableHeight = canvasHeight * (1 - 2 * Canvas.margin)
    let scale = min(usableWidth / bounds.width, usableHeight / bounds.height)
    return CGAffineTransform(translationX: -bounds.midX, y: -bounds.midY)
        .concatenating(CGAffineTransform(scaleX: scale, y: scale))
        .concatenating(CGAffineTransform(translationX: canvasWidth / 2, y: canvasHeight / 2))
}

func makeContext(width: Int, height: Int) throws -> CGContext {
    guard let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { throw Failure("Couldn't create a \(width) x \(height) canvas") }
    context.interpolationQuality = .high
    return context
}

/// Draws the cutout onto a transparent canvas with `transform` (top-left coordinates).
func render(_ cutout: CGImage, with transform: CGAffineTransform) throws -> CGImage {
    let context = try makeContext(width: Canvas.width, height: Canvas.height)
    // Core Graphics measures from the bottom-left, so flip into top-left space and back.
    let photoToTopLeft = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(cutout.height))
    let canvasToBottomLeft = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(Canvas.height))
    context.concatenate(photoToTopLeft.concatenating(transform).concatenating(canvasToBottomLeft))
    context.draw(cutout, in: CGRect(x: 0, y: 0, width: cutout.width, height: cutout.height))
    guard let image = context.makeImage() else { throw Failure("Couldn't render the canvas") }
    return image
}

// MARK: Debug images

/// Draws on top of `image` in top-left coordinates.
func annotate(_ image: CGImage, drawing: (CGContext) -> Void) throws -> CGImage {
    let context = try makeContext(width: image.width, height: image.height)
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    context.translateBy(x: 0, y: CGFloat(image.height))
    context.scaleBy(x: 1, y: -1)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    drawing(context)
    NSGraphicsContext.current = nil
    guard let output = context.makeImage() else { throw Failure("Couldn't draw the debug image") }
    return output
}

func gridImage(_ cutout: CGImage) throws -> CGImage {
    try annotate(cutout) { context in
        let step = 100
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: max(14, CGFloat(cutout.width) / 60), weight: .bold),
            .foregroundColor: NSColor.systemRed,
        ]
        context.setStrokeColor(NSColor.systemRed.withAlphaComponent(0.45).cgColor)
        context.setLineWidth(max(1, CGFloat(cutout.width) / 800))
        for x in stride(from: 0, to: cutout.width, by: step) {
            context.strokeLineSegments(between: [CGPoint(x: x, y: 0), CGPoint(x: x, y: cutout.height)])
            NSString(string: "\(x)").draw(at: CGPoint(x: x + 3, y: 3), withAttributes: attributes)
        }
        for y in stride(from: step, to: cutout.height, by: step) {
            context.strokeLineSegments(between: [CGPoint(x: 0, y: y), CGPoint(x: cutout.width, y: y)])
            NSString(string: "\(y)").draw(at: CGPoint(x: 3, y: y + 3), withAttributes: attributes)
        }
    }
}

func previewImage(_ canvas: CGImage) throws -> CGImage {
    try annotate(canvas) { context in
        context.setStrokeColor(NSColor.systemPink.cgColor)
        context.setLineWidth(1)
        context.stroke(CGRect(x: 0, y: 0, width: Canvas.width, height: Canvas.height).insetBy(dx: 0.5, dy: 0.5))
        context.setFillColor(NSColor.systemRed.cgColor)
        for point in [Canvas.leftShoulder, Canvas.rightShoulder] {
            context.fillEllipse(in: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12))
        }
    }
}

// MARK: Saving

func writePNG(_ image: CGImage, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw Failure("Can't write \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw Failure("Couldn't save \(url.path)") }
}

/// Saves the canvas as <assets>/<id>.imageset, replacing any earlier image for that garment.
/// The new imageset is built in a temporary folder first, so a failed write keeps the old one.
func saveToAssetCatalog(_ image: CGImage, id: String, assets: URL) throws -> URL {
    let files = FileManager.default
    guard files.fileExists(atPath: assets.appendingPathComponent("Contents.json").path) else {
        throw Failure("\(assets.path) isn't an asset catalog. Run from the repo root or pass --assets.")
    }
    let imageSet = assets.appendingPathComponent("\(id).imageset")
    let staging = try files.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: assets, create: true)
    defer { try? files.removeItem(at: staging) }
    let staged = staging.appendingPathComponent("\(id).imageset")
    try writePNG(image, to: staged.appendingPathComponent("\(id).png"))
    let contents = """
    {
      "images" : [
        {
          "filename" : "\(id).png",
          "idiom" : "universal"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }

    """
    try contents.write(to: staged.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    if files.fileExists(atPath: imageSet.path) {
        _ = try files.replaceItemAt(imageSet, withItemAt: staged)
    } else {
        try files.moveItem(at: staged, to: imageSet)
    }
    return imageSet
}

// MARK: Main

/// The guess, unless it's too narrow to be shoulders, as with a hanger hook or a halter strap.
func guessedShoulders(from alpha: AlphaMap, in bounds: CGRect) throws -> (left: CGPoint, right: CGPoint)? {
    guard let guess = alpha.guessShoulders(in: bounds) else { return nil }
    guard guess.right.x - guess.left.x >= bounds.width * 0.25 else {
        throw Failure("The shoulder guess is only \(Int(guess.right.x - guess.left.x)) px wide. Pass --shoulders, reading them off --grid.")
    }
    return guess
}

func run() throws {
    let options = try Options(arguments: Array(CommandLine.arguments.dropFirst()))
    let photo = try loadImage(options.photo)
    let separated = options.keepBackground ? photo : try removeBackground(photo)
    let cutout = try options.clearAbove.map { try clearing(separated, above: $0) } ?? separated
    let alpha = try AlphaMap(cutout)
    guard let bounds = alpha.solidBounds else { throw Failure("The cutout is empty") }
    print("Photo \(photo.width) x \(photo.height), garment at x \(Int(bounds.minX))-\(Int(bounds.maxX)), y \(Int(bounds.minY))-\(Int(bounds.maxY))")

    if let gridURL = options.gridURL {
        try writePNG(try gridImage(cutout), to: gridURL)
        print("Grid: \(gridURL.path)")
    }

    var shoulders: (left: CGPoint, right: CGPoint)?
    if options.isTop {
        shoulders = try options.shoulders ?? guessedShoulders(from: alpha, in: bounds)
        guard let shoulders else { throw Failure("Couldn't guess the shoulders. Pass --shoulders.") }
        let source = options.shoulders == nil ? "guessed" : "given"
        print("Shoulders (\(source)): left \(Int(shoulders.left.x)),\(Int(shoulders.left.y)) right \(Int(shoulders.right.x)),\(Int(shoulders.right.y))")
    }

    let transform = placement(for: bounds, shoulders: shoulders)
    guard [transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty].allSatisfy(\.isFinite) else {
        throw Failure("Couldn't place the garment. Check the shoulder points.")
    }
    let placed = bounds.applying(transform)
    let canvasRect = CGRect(x: 0, y: 0, width: Canvas.width, height: Canvas.height)
    if !canvasRect.contains(placed.insetBy(dx: 1, dy: 1)) {
        let problem = "The garment runs off the canvas (it lands at \(placed.integral))."
        guard options.force else {
            throw Failure("\(problem) Check the shoulder points, or pass --force to crop it.")
        }
        print("Warning: \(problem) Cropping it because of --force.")
    }
    let canvas = try render(cutout, with: transform)

    if let previewURL = options.previewURL {
        try writePNG(try previewImage(canvas), to: previewURL)
        print("Preview: \(previewURL.path)")
    }
    let imageSet = try saveToAssetCatalog(canvas, id: options.garmentID, assets: options.assets)
    print("Saved \(imageSet.path)")
}

do {
    try run()
} catch {
    FileHandle.standardError.write(Data("prep-garment: \(error)\n".utf8))
    exit(1)
}
