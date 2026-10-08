// Original installer artwork, rendered from vectors and the MIT-licensed bundled minis.
// Coordinates are in Finder points; export both 1x and 2x for a Retina TIFF.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct InstallerArt {
    static let size = CGSize(width: 640, height: 360)
    let context: CGContext
    let resources: URL

    func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
        CGColor(red: CGFloat((hex >> 16) & 255) / 255,
                green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255, alpha: alpha)
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
        context.setFillColor(color(0xFAFCFA))
        context.fill(CGRect(origin: .zero, size: Self.size))

        // A quiet dot grid keeps the canvas light, with no text or painted icons.
        context.setFillColor(color(0x9EADA2, alpha: 0.16))
        for x in stride(from: 12, through: 640, by: 20) {
            for y in stride(from: 10, through: 360, by: 20) {
                context.fillEllipse(in: CGRect(x: CGFloat(x), y: CGFloat(y), width: 1, height: 1))
            }
        }

        // Five identical chevrons gain contrast toward the Applications target.
        context.setLineWidth(3.5)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        for (index, hex) in [0xE3E8E3, 0xCBD4CC, 0xA0B0A4, 0x718674, 0x3E5744].enumerated() {
            let x = CGFloat(260 + index * 26)
            let arrow = CGMutablePath()
            arrow.move(to: CGPoint(x: x, y: 138))
            arrow.addLine(to: CGPoint(x: x + 10, y: 148))
            arrow.addLine(to: CGPoint(x: x, y: 158))
            context.addPath(arrow)
            context.setStrokeColor(color(UInt32(hex)))
            context.strokePath()
        }

        // The minis are small corner details; the installation icons own the center.
        try mini("Mochi", row: 0, column: 0, rect: CGRect(x: 22, y: 263, width: 74, height: 80))
        try mini("Paris", row: 0, column: 0, rect: CGRect(x: 544, y: 263, width: 74, height: 80))
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
