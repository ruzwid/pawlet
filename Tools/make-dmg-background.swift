// Original installer artwork, rendered from vectors and the MIT-licensed bundled minis.
// Coordinates are in Finder points; export both 1x and 2x for a Retina TIFF.
import AppKit
import ImageIO
import UniformTypeIdentifiers

struct InstallerArt {
    static let size = CGSize(width: 800, height: 540)
    let context: CGContext
    let resources: URL

    func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255, alpha: alpha)
    }

    func ellipse(_ rect: CGRect, _ hex: UInt32, alpha: CGFloat = 1) {
        context.setFillColor(color(hex, alpha: alpha).cgColor)
        context.fillEllipse(in: rect)
    }

    func text(_ value: String, at point: CGPoint, size: CGFloat,
              weight: NSFont.Weight = .regular, hex: UInt32 = 0x284D49) {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        let font = base.fontDescriptor.withDesign(.rounded)
            .flatMap { NSFont(descriptor: $0, size: size) } ?? base
        (value as NSString).draw(at: point, withAttributes: [
            .font: font, .foregroundColor: color(hex)
        ])
    }

    func cloud(x: CGFloat, y: CGFloat, width: CGFloat, tint: UInt32 = 0xFFFFFF) {
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 8), blur: 24,
                          color: color(0x568284, alpha: 0.13).cgColor)
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(x: x, y: y + width * 0.12, width: width, height: width * 0.25))
        path.addEllipse(in: CGRect(x: x + width * 0.13, y: y + width * 0.03,
                                  width: width * 0.38, height: width * 0.32))
        path.addEllipse(in: CGRect(x: x + width * 0.41, y: y,
                                  width: width * 0.34, height: width * 0.34))
        path.addEllipse(in: CGRect(x: x + width * 0.66, y: y + width * 0.09,
                                  width: width * 0.24, height: width * 0.25))
        context.addPath(path)
        context.setFillColor(color(tint).cgColor)
        context.fillPath()
        context.restoreGState()
    }

    func sparkle(x: CGFloat, y: CGFloat, radius: CGFloat, tint: UInt32 = 0x8EAB9C) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: y - radius))
        path.addQuadCurve(to: CGPoint(x: x + radius, y: y), control: CGPoint(x: x + 1, y: y - 1))
        path.addQuadCurve(to: CGPoint(x: x, y: y + radius), control: CGPoint(x: x + 1, y: y + 1))
        path.addQuadCurve(to: CGPoint(x: x - radius, y: y), control: CGPoint(x: x - 1, y: y + 1))
        path.addQuadCurve(to: CGPoint(x: x, y: y - radius), control: CGPoint(x: x - 1, y: y - 1))
        context.addPath(path)
        context.setFillColor(color(tint).cgColor)
        context.fillPath()
    }

    func paw(x: CGFloat, y: CGFloat, scale: CGFloat, angle: CGFloat, alpha: CGFloat) {
        context.saveGState()
        context.translateBy(x: x, y: y)
        context.rotate(by: angle)
        context.scaleBy(x: scale, y: scale)
        ellipse(CGRect(x: -7, y: -2, width: 14, height: 11), 0x608C79, alpha: alpha)
        for (px, py) in [(-9.0, -8.0), (-3.0, -12.0), (4.0, -12.0), (10.0, -7.0)] {
            ellipse(CGRect(x: px - 2.5, y: py, width: 5, height: 7), 0x608C79, alpha: alpha)
        }
        context.restoreGState()
    }

    func mini(_ name: String, row: Int, column: Int, rect: CGRect) throws {
        let url = resources.appendingPathComponent("Pets/\(name)/spritesheet.png")
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let atlas = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let frame = atlas.cropping(to: CGRect(x: column * 192, y: row * 208, width: 192, height: 208)) else {
            throw NSError(domain: "InstallerArt", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot read bundled mini \(name)"])
        }
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.interpolationQuality = .high
        context.draw(frame, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }

    func draw() throws {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let gradient = CGGradient(colorsSpace: space, colors: [
            color(0xF2F7ED).cgColor, color(0xE4F1ED).cgColor, color(0xDDE9F6).cgColor
        ] as CFArray, locations: [0, 0.5, 1])!
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 800, y: 540), options: [])

        // Large clipped cloud shapes frame the scene without competing with the install targets.
        ellipse(CGRect(x: -160, y: 355, width: 345, height: 280), 0xD0E4E7, alpha: 0.7)
        ellipse(CGRect(x: 690, y: -95, width: 230, height: 240), 0xDEE7CA, alpha: 0.6)
        ellipse(CGRect(x: 670, y: 320, width: 225, height: 230), 0xE3DEF0, alpha: 0.7)
        cloud(x: -36, y: 172, width: 150, tint: 0xF8FBF5)
        cloud(x: 710, y: 231, width: 145, tint: 0xF6F8FC)

        paw(x: 56, y: 34, scale: 0.7, angle: 0, alpha: 1)
        text("Pawlet", at: CGPoint(x: 75, y: 19), size: 21, weight: .bold)
        text("Make room for", at: CGPoint(x: 44, y: 66), size: 38, weight: .bold)
        text("little friends.", at: CGPoint(x: 44, y: 108), size: 38, weight: .bold)
        text("Drag Pawlet to Applications to bring them home.",
             at: CGPoint(x: 46, y: 165), size: 16, hex: 0x486B65)

        // Mochi floats above the destination; Paris watches from the lower-left cloud.
        cloud(x: 543, y: 114, width: 169)
        try mini("Mochi", row: 3, column: 2, rect: CGRect(x: 568, y: 12, width: 122, height: 132))
        sparkle(x: 706, y: 87, radius: 9)
        sparkle(x: 537, y: 60, radius: 5)
        ellipse(CGRect(x: 708, y: 38, width: 5, height: 5), 0x8EAB9C)

        // Native Finder icons sit on the islands. These are deliberately not baked into the image.
        for x: CGFloat in [230, 570] {
            ellipse(CGRect(x: x - 86, y: 218, width: 172, height: 125), 0xFFFFFF, alpha: 0.42)
            cloud(x: x - 108, y: 314, width: 216)
        }
        paw(x: 343, y: 282, scale: 0.65, angle: 0.9, alpha: 0.5)
        paw(x: 379, y: 265, scale: 0.7, angle: 1.2, alpha: 0.65)
        paw(x: 416, y: 263, scale: 0.75, angle: 1.6, alpha: 0.8)
        let arrow = CGMutablePath()
        arrow.move(to: CGPoint(x: 450, y: 266))
        arrow.addLine(to: CGPoint(x: 477, y: 277))
        arrow.addLine(to: CGPoint(x: 452, y: 293))
        context.addPath(arrow)
        context.setStrokeColor(color(0x608C79).cgColor)
        context.setLineWidth(3)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.strokePath()

        cloud(x: 27, y: 447, width: 248, tint: 0xF9FBFF)
        try mini("Paris", row: 0, column: 0, rect: CGRect(x: 60, y: 353, width: 164, height: 178))
        sparkle(x: 256, y: 422, radius: 8, tint: 0x9DA5C2)
        sparkle(x: 36, y: 387, radius: 5, tint: 0x9DA5C2)
        text("Then open Pawlet", at: CGPoint(x: 315, y: 430), size: 19, weight: .semibold)
        text("from Applications.", at: CGPoint(x: 315, y: 457), size: 16, hex: 0x486B65)
        text("Mochi & Paris are already inside.", at: CGPoint(x: 315, y: 503), size: 12, hex: 0x486B65)
    }
}

func render(resources: URL, output: URL, scale: Int) throws {
    let width = Int(InstallerArt.size.width) * scale
    let height = Int(InstallerArt.size.height) * scale
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        throw NSError(domain: "InstallerArt", code: 2)
    }
    context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    context.translateBy(x: 0, y: InstallerArt.size.height)
    context.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    defer { NSGraphicsContext.restoreGraphicsState() }
    try InstallerArt(context: context, resources: resources).draw()
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "InstallerArt", code: 3)
    }
    CGImageDestinationAddImage(destination, image, [
        kCGImagePropertyDPIWidth: 72 * scale,
        kCGImagePropertyDPIHeight: 72 * scale
    ] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "InstallerArt", code: 4) }
}

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: make-dmg-background RESOURCES OUTPUT_DIRECTORY\n", stderr)
    exit(1)
}
let resources = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
try render(resources: resources, output: output.appendingPathComponent("background.png"), scale: 1)
try render(resources: resources, output: output.appendingPathComponent("background@2x.png"), scale: 2)
