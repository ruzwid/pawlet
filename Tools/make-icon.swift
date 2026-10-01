import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Reproducible vector app mark, independent of any installed character.
let destinationURL = URL(fileURLWithPath: CommandLine.arguments[1])
let colorSpace = CGColorSpaceCreateDeviceRGB()
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
    bytesPerRow: 4096, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.addPath(CGPath(roundedRect: CGRect(x: 28, y: 28, width: 968, height: 968), cornerWidth: 220, cornerHeight: 220, transform: nil))
context.clip()
let gradient = CGGradient(colorsSpace: colorSpace,
    colors: [CGColor(red: 0.95, green: 0.97, blue: 0.98, alpha: 1), CGColor(red: 0.78, green: 0.87, blue: 0.92, alpha: 1)] as CFArray,
    locations: [0, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [])
context.setFillColor(CGColor(red: 0.24, green: 0.43, blue: 0.57, alpha: 1))
for (x, y, angle) in [(270.0, 570.0, 0.45), (410.0, 710.0, 0.15), (610.0, 710.0, -0.15), (750.0, 570.0, -0.45)] {
    context.saveGState(); context.translateBy(x: x, y: y); context.rotate(by: angle)
    context.fillEllipse(in: CGRect(x: -72, y: -95, width: 144, height: 190)); context.restoreGState()
}
let pad = CGMutablePath()
pad.move(to: CGPoint(x: 290, y: 265))
pad.addCurve(to: CGPoint(x: 405, y: 490), control1: CGPoint(x: 220, y: 310), control2: CGPoint(x: 350, y: 425))
pad.addCurve(to: CGPoint(x: 620, y: 490), control1: CGPoint(x: 455, y: 550), control2: CGPoint(x: 570, y: 550))
pad.addCurve(to: CGPoint(x: 735, y: 265), control1: CGPoint(x: 685, y: 425), control2: CGPoint(x: 805, y: 310))
pad.addCurve(to: CGPoint(x: 512, y: 285), control1: CGPoint(x: 680, y: 210), control2: CGPoint(x: 585, y: 265))
pad.addCurve(to: CGPoint(x: 290, y: 265), control1: CGPoint(x: 440, y: 265), control2: CGPoint(x: 345, y: 210))
pad.closeSubpath(); context.addPath(pad); context.fillPath()
let image = context.makeImage()!
let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
precondition(CGImageDestinationFinalize(destination))
