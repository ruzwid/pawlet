import Foundation
import ImageIO
import CryptoKit

struct CodexPetMetadata: Codable {
    var id: String?
    var displayName: String?
    var description: String?
    var spriteVersionNumber: Int?
    var spritesheetPath: String?

    func manifest(fallbackID: String) throws -> PetManifest {
        let identifier = id ?? CodexPetTransfer.localID(from: fallbackID)
        let manifest = PetManifest(id: identifier, name: displayName ?? identifier,
            description: description ?? "", spriteVersion: spriteVersionNumber ?? 1)
        try manifest.validate()
        return manifest
    }
}

enum TransferConstants {
    static let MAX_METADATA_BYTES = 65_536
    static let MAX_IMAGE_BYTES = 20 * 1024 * 1024
    static let MAX_ARCHIVE_BYTES = 25 * 1024 * 1024
    static let MAX_COMPATIBLE_ZIP_ENTRIES = 32
}

enum CodexPetTransfer {
    static func localID(from name: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        let identifier = String(name.unicodeScalars.map { allowed.contains($0) ? String($0) : "-" }.joined().prefix(64))
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return identifier.isEmpty ? UUID().uuidString.lowercased() : identifier
    }

    static func copyRegularFile(_ source: URL, to destination: URL, maximumBytes: Int) throws {
        let values = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size > 0, size <= maximumBytes else {
            throw PetLibraryError.invalid("Mini files must be plain files within the size limits.")
        }
        try FileManager.default.copyItem(at: source, to: destination)
        guard (try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= maximumBytes else {
            throw PetLibraryError.invalid("A mini file changed during import. Try again.")
        }
    }

    static func prepareFolder(_ source: URL, fallbackID: String) throws -> URL {
        let snapshot = FileManager.default.temporaryDirectory.appendingPathComponent("codex-pet-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: snapshot, withIntermediateDirectories: true)
        do {
            let metadataURL = snapshot.appendingPathComponent("pet.json")
            try copyRegularFile(source.appendingPathComponent("pet.json"), to: metadataURL, maximumBytes: TransferConstants.MAX_METADATA_BYTES)
            let metadata = try JSONDecoder().decode(CodexPetMetadata.self, from: Data(contentsOf: metadataURL))
            let imageName = metadata.spritesheetPath ?? "spritesheet.webp"
            guard ["spritesheet.png", "spritesheet.webp"].contains(imageName) else {
                throw PetLibraryError.invalid("Keep pet.json beside spritesheet.png or spritesheet.webp. Nested or external image paths are not supported.")
            }
            let imageURL = snapshot.appendingPathComponent(imageName)
            try copyRegularFile(source.appendingPathComponent(imageName), to: imageURL, maximumBytes: TransferConstants.MAX_IMAGE_BYTES)
            var manifest = try metadata.manifest(fallbackID: fallbackID)
            if imageName == "spritesheet.webp" {
                let image = try SpriteAtlas.readImage(imageURL, allowWebP: true)
                let pngURL = snapshot.appendingPathComponent("spritesheet.png")
                guard let writer = CGImageDestinationCreateWithURL(pngURL as CFURL, "public.png" as CFString, 1, nil) else {
                    throw PetLibraryError.invalid("Couldn't convert the WebP sprite sheet to PNG.")
                }
                CGImageDestinationAddImage(writer, image, nil)
                guard CGImageDestinationFinalize(writer) else { throw PetLibraryError.invalid("Couldn't save the converted sprite sheet.") }
            }
            manifest.artworkSHA256 = SHA256.hash(data: try Data(contentsOf: snapshot.appendingPathComponent("spritesheet.png")))
                .map { String(format: "%02x", $0) }.joined()
            try PetLibrary.write(manifest, to: snapshot)
            _ = try SpriteAtlas(manifest: manifest, directory: snapshot)
            return snapshot
        } catch {
            try? FileManager.default.removeItem(at: snapshot)
            throw error
        }
    }

    static func export(_ pet: LibraryPet, to destination: URL) throws {
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw PetLibraryError.invalid("That folder already exists. Choose a new folder to keep the existing mini intact.")
        }
        let parent = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let snapshot = parent.appendingPathComponent(".pawlet-export-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: snapshot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: snapshot) }
        try copyRegularFile(pet.directory.appendingPathComponent("spritesheet.png"), to: snapshot.appendingPathComponent("spritesheet.png"), maximumBytes: TransferConstants.MAX_IMAGE_BYTES)
        try PetLibrary.write(pet.manifest, to: snapshot)
        _ = try SpriteAtlas(manifest: pet.manifest, directory: snapshot)
        let metadata = CodexPetMetadata(id: pet.id, displayName: pet.manifest.name, description: pet.manifest.description,
            spriteVersionNumber: pet.manifest.spriteVersion, spritesheetPath: "spritesheet.png")
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(metadata).write(to: snapshot.appendingPathComponent("pet.json"))
        try FileManager.default.moveItem(at: snapshot, to: destination)
    }
}
