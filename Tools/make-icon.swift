import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let colorSpace = CGColorSpaceCreateDeviceRGB()
let drawPaw: (CGContext, CGColor) -> Void = { context, color in
    context.setFillColor(color)
    for (centerX, centerY, rotation) in [(233.0, 589.0, 0.42), (407.0, 734.0, 0.15), (617.0, 734.0, -0.15), (791.0, 589.0, -0.42)] {
        context.saveGState(); context.translateBy(x: centerX, y: centerY); context.rotate(by: rotation)
        context.fillEllipse(in: CGRect(x: -79, y: -106, width: 158, height: 212)); context.restoreGState()
    }
    let pad = CGMutablePath()
    pad.move(to: CGPoint(x: 512, y: 213))
    pad.addCurve(to: CGPoint(x: 286, y: 253), control1: CGPoint(x: 404, y: 213), control2: CGPoint(x: 311, y: 214))
    pad.addCurve(to: CGPoint(x: 288, y: 389), control1: CGPoint(x: 240, y: 274), control2: CGPoint(x: 250, y: 330))
    pad.addCurve(to: CGPoint(x: 512, y: 554), control1: CGPoint(x: 367, y: 521), control2: CGPoint(x: 442, y: 554))
    pad.addCurve(to: CGPoint(x: 736, y: 389), control1: CGPoint(x: 582, y: 554), control2: CGPoint(x: 657, y: 521))
    pad.addCurve(to: CGPoint(x: 738, y: 253), control1: CGPoint(x: 774, y: 330), control2: CGPoint(x: 784, y: 274))
    pad.addCurve(to: CGPoint(x: 512, y: 213), control1: CGPoint(x: 713, y: 214), control2: CGPoint(x: 620, y: 213))
    pad.closeSubpath(); context.addPath(pad); context.fillPath()
}
let writePNG: (CGImage, String) -> Void = { image, path in
    let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    precondition(CGImageDestinationFinalize(destination))
}
let iconContext = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
    bytesPerRow: 4096, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
iconContext.addPath(CGPath(roundedRect: CGRect(x: 28, y: 28, width: 968, height: 968), cornerWidth: 235, cornerHeight: 235, transform: nil))
iconContext.clip()
let backgroundGradient = CGGradient(colorsSpace: colorSpace,
    colors: [CGColor(red: 1.0, green: 0.98, blue: 0.94, alpha: 1), CGColor(red: 1.0, green: 0.91, blue: 0.88, alpha: 1)] as CFArray, locations: [0, 1])!
iconContext.drawLinearGradient(backgroundGradient, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [])
drawPaw(iconContext, CGColor(red: 1.0, green: 0.48, blue: 0.49, alpha: 1))
writePNG(iconContext.makeImage()!, CommandLine.arguments[1])
if CommandLine.arguments.count > 2 {
    let markContext = CGContext(data: nil, width: 128, height: 128, bitsPerComponent: 8,
        bytesPerRow: 512, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    markContext.scaleBy(x: 1.0 / 6, y: 1.0 / 6); markContext.translateBy(x: -128, y: -146)
    drawPaw(markContext, CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    writePNG(markContext.makeImage()!, CommandLine.arguments[2])
}
