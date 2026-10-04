import AppKit
import ImageIO

enum AtlasCompatibilityTests {
    static func run(sample: LibraryPet, scratch: URL) throws {
        let source = try SpriteAtlas.readImage(sample.directory.appendingPathComponent("spritesheet.png"))
        guard let context = CGContext(data: nil, width: source.width, height: source.height, bitsPerComponent: 8,
            bytesPerRow: source.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
            let idleCell = source.cropping(to: CGRect(x: 0, y: 0, width: 192, height: 208)) else {
            throw PetLibraryError.invalid("Couldn't prepare atlas compatibility fixture")
        }
        context.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
        context.draw(idleCell, in: CGRect(x: 6 * 192, y: source.height - 208, width: 192, height: 208))
        let folder = scratch.appendingPathComponent("extra-idle-fixture", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var manifest = sample.manifest
        manifest.id = "extra-idle-fixture"; manifest.artworkSHA256 = nil
        try PetLibrary.write(manifest, to: folder)
        let imageURL = folder.appendingPathComponent("spritesheet.png")
        try write(context, to: imageURL)
        let bytesBeforeImport = try Data(contentsOf: imageURL)
        let library = try PetLibrary(root: scratch.appendingPathComponent("extra-idle-library"))
        let imported = try library.importFile(folder)
        let atlas = try SpriteAtlas(manifest: imported.manifest, directory: imported.directory)
        try ProjectTests.require(atlas.populatedCount == 73, "Unused cell entered the playable frame cache")
        try ProjectTests.require(atlas.frame(SpriteFrame(row: 0, column: 6)) === atlas.frame(SpriteFrame(row: 0, column: 0)), "Unused frame must remain unplayable")
        let importedBytes = try Data(contentsOf: imported.directory.appendingPathComponent("spritesheet.png"))
        try ProjectTests.require(importedBytes == bytesBeforeImport, "Runtime import must preserve extra-frame image bytes")
        context.clear(CGRect(x: 0, y: source.height - 208, width: 192, height: 208))
        try write(context, to: imageURL)
        try ProjectTests.reject("empty required idle frame") { _ = try SpriteAtlas(manifest: manifest, directory: folder) }
    }

    static func write(_ context: CGContext, to url: URL) throws {
        guard let image = context.makeImage(), let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            throw PetLibraryError.invalid("Couldn't encode compatibility fixture")
        }
        CGImageDestinationAddImage(destination, image, nil)
        try ProjectTests.require(CGImageDestinationFinalize(destination), "Compatibility fixture encoding failed")
    }
}
