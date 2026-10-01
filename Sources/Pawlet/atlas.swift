import AppKit
import CryptoKit
import ImageIO

enum AtlasError: Error, LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let reason) = self { return reason }; return nil }
}

final class SpriteAtlas {
    let manifest: PetManifest
    var name: String { manifest.name }
    var id: String { manifest.id }
    let hash: String
    let image: CGImage
    var hasLookDirections: Bool { manifest.spriteVersion == 2 }
    private var frames: [String: NSImage] = [:]
    private var alphaMasks: [String: [UInt8]] = [:]

    static func readImage(_ url: URL) throws -> CGImage {
        guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 20 * 1024 * 1024 else {
            throw AtlasError.invalid("The sprite sheet exceeds 20 MB.")
        }
        let data = try Data(contentsOf: url)
        guard !data.isEmpty, let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetType(source) as String? == "public.png",
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width == 1536, [1872, 2288].contains(height),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw AtlasError.invalid("Use a transparent PNG sprite sheet measuring 1536 × 2288 (v2), or 1536 × 1872 (v1). A regular photo or GIF isn't a complete pet.")
        }
        guard [.first, .last, .premultipliedFirst, .premultipliedLast].contains(image.alphaInfo) else {
            throw AtlasError.invalid("The sprite sheet needs a transparent background.")
        }
        return image
    }

    init(manifest: PetManifest, directory: URL) throws {
        try manifest.validate(); self.manifest = manifest
        let url = directory.appendingPathComponent("spritesheet.png")
        image = try Self.readImage(url)
        let expectedHeight = manifest.spriteVersion == 2 ? 2288 : 1872
        guard image.height == expectedHeight else { throw AtlasError.invalid("The manifest's spriteVersion doesn't match the image height.") }
        hash = SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
        if let expected = manifest.artworkSHA256, hash != expected.lowercased() { throw AtlasError.invalid("The artwork hash doesn't match. The file may be damaged.") }
        let counts = [6, 8, 8, 4, 5, 8, 6, 6, 6] + (hasLookDirections ? [8, 8] : [])
        for (row, count) in counts.enumerated() {
            for column in 0..<8 {
                let rect = CGRect(x: column * 192, y: row * 208, width: 192, height: 208)
                guard let cell = image.cropping(to: rect) else { throw AtlasError.invalid("Missing frame.") }
                var rgba = [UInt8](repeating: 0, count: 192 * 208 * 4)
                rgba.withUnsafeMutableBytes { bytes in
                    let context = CGContext(data: bytes.baseAddress, width: 192, height: 208,
                        bitsPerComponent: 8, bytesPerRow: 192 * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                    context.draw(cell, in: CGRect(x: 0, y: 0, width: 192, height: 208))
                }
                let alpha = stride(from: 3, to: rgba.count, by: 4).map { rgba[$0] }
                let visible = alpha.contains { $0 > 0 }
                if column >= count {
                    guard !visible else { throw AtlasError.invalid("Unused cell in row \(row) isn't transparent.") }
                    continue
                }
                guard visible else { throw AtlasError.invalid("Row \(row), frame \(column) is empty.") }
                // Fully opaque cells usually indicate a background panel left behind.
                guard alpha.contains(0) else { throw AtlasError.invalid("Row \(row), frame \(column) has an opaque background.") }
                frames["\(row):\(column)"] = NSImage(cgImage: cell, size: NSSize(width: 192, height: 208))
                alphaMasks["\(row):\(column)"] = alpha
            }
        }
    }

    func frame(_ frame: SpriteFrame) -> NSImage { frames["\(frame.row):\(frame.column)"] ?? frames["0:0"]! }
    var populatedCount: Int { frames.count }

    func isOpaque(_ frame: SpriteFrame, x: Int, topY: Int) -> Bool {
        guard x >= 0, x < 192, topY >= 0, topY < 208, let mask = alphaMasks["\(frame.row):\(frame.column)"] else { return false }
        for y in max(0, topY - 3)...min(207, topY + 3) {
            for column in max(0, x - 3)...min(191, x + 3) { if mask[y * 192 + column] > 24 { return true } }
        }
        return false
    }

    static func thumbnail(directory: URL) throws -> NSImage {
        let atlas = try readImage(directory.appendingPathComponent("spritesheet.png"))
        let cell = atlas.cropping(to: CGRect(x: 0, y: 0, width: 192, height: 208))!
        let context = CGContext(data: nil, width: 192, height: 208, bitsPerComponent: 8, bytesPerRow: 768,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(cell, in: CGRect(x: 0, y: 0, width: 192, height: 208))
        return NSImage(cgImage: context.makeImage()!, size: NSSize(width: 192, height: 208))
    }
}
