import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let colorSpace = CGColorSpaceCreateDeviceRGB()
let drawPaw: (CGContext, CGColor) -> Void = { context, color in
    context.setFillColor(color)
    for (centerX, centerY, rotation) in [(326.0, 618.0, 0.36), (439.0, 714.0, 0.12), (585.0, 714.0, -0.12), (698.0, 618.0, -0.36)] {
        context.saveGState(); context.translateBy(x: centerX, y: centerY); context.rotate(by: rotation)
        context.fillEllipse(in: CGRect(x: -65, y: -76, width: 130, height: 152)); context.restoreGState()
    }
    let pad = CGMutablePath()
    pad.move(to: CGPoint(x: 341, y: 282))
    pad.addCurve(to: CGPoint(x: 363, y: 454), control1: CGPoint(x: 267, y: 310), control2: CGPoint(x: 307, y: 402))
    pad.addCurve(to: CGPoint(x: 512, y: 555), control1: CGPoint(x: 411, y: 503), control2: CGPoint(x: 444, y: 555))
    pad.addCurve(to: CGPoint(x: 661, y: 454), control1: CGPoint(x: 580, y: 555), control2: CGPoint(x: 613, y: 503))
    pad.addCurve(to: CGPoint(x: 683, y: 282), control1: CGPoint(x: 717, y: 402), control2: CGPoint(x: 757, y: 310))
    pad.addCurve(to: CGPoint(x: 512, y: 299), control1: CGPoint(x: 619, y: 258), control2: CGPoint(x: 570, y: 299))
    pad.addCurve(to: CGPoint(x: 341, y: 282), control1: CGPoint(x: 454, y: 299), control2: CGPoint(x: 405, y: 258))
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
    colors: [CGColor(red: 0.96, green: 0.98, blue: 0.99, alpha: 1), CGColor(red: 0.80, green: 0.90, blue: 0.95, alpha: 1)] as CFArray, locations: [0, 1])!
iconContext.drawLinearGradient(backgroundGradient, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [])
drawPaw(iconContext, CGColor(red: 0.25, green: 0.46, blue: 0.60, alpha: 1))
writePNG(iconContext.makeImage()!, CommandLine.arguments[1])
if CommandLine.arguments.count > 2 {
    let markContext = CGContext(data: nil, width: 128, height: 128, bitsPerComponent: 8,
        bytesPerRow: 512, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    markContext.scaleBy(x: 0.19, y: 0.19); markContext.translateBy(x: -175, y: -204)
    drawPaw(markContext, CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    writePNG(markContext.makeImage()!, CommandLine.arguments[2])
}
