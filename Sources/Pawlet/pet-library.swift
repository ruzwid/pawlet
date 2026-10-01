import Foundation
import CryptoKit

struct PetManifest: Codable, Identifiable, Hashable {
    var schemaVersion: Int = 1
    var id: String
    var name: String
    var description: String
    var spriteVersion: Int = 2
    var atlas: String = "spritesheet.png"
    var author: String?
    var artworkSHA256: String?

    func validate() throws {
        guard schemaVersion == 1, [1, 2].contains(spriteVersion), atlas == "spritesheet.png" else {
            throw PetLibraryError.invalid("This pet uses an unsupported format. Use schemaVersion 1 and spriteVersion 1 or 2.")
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        guard !id.isEmpty, id.utf8.count <= 64, id.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw PetLibraryError.invalid("The pet ID must be 1–64 letters, numbers, hyphens or underscores.")
        }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 60,
              !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              description.count <= 600, (author?.count ?? 0) <= 100 else {
            throw PetLibraryError.invalid("The pet name or description is too long or invalid.")
        }
        if let hash = artworkSHA256 {
            guard hash.count == 64, hash.allSatisfy({ $0.isHexDigit }) else { throw PetLibraryError.invalid("Invalid artwork hash.") }
        }
    }
}

struct LibraryPet: Identifiable {
    var manifest: PetManifest
    let directory: URL
    var id: String { manifest.id }
}

enum PetLibraryError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let reason) = self { return reason }; return nil }
}

final class PetLibrary {
    let root: URL
    let fileManager = FileManager.default
    private(set) var issues: [String] = []

    init(root: URL) throws {
        self.root = root
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func list() -> [LibraryPet] {
        issues = []
        let directories = (try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        return directories.compactMap { folder in
            do {
                guard try folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { return nil }
                let manifest = try readManifest(folder)
                return LibraryPet(manifest: manifest, directory: folder)
            } catch { issues.append("\(folder.lastPathComponent): \(error.localizedDescription)"); return nil }
        }.sorted { $0.manifest.name.localizedStandardCompare($1.manifest.name) == .orderedAscending }
    }

    func readManifest(_ folder: URL) throws -> PetManifest {
        let path = folder.appendingPathComponent("manifest.json")
        guard (try path.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 65_536 else { throw PetLibraryError.invalid("The manifest is too large.") }
        let manifest = try JSONDecoder().decode(PetManifest.self, from: Data(contentsOf: path))
        try manifest.validate()
        return manifest
    }

    func seed(from bundled: URL, excluding removed: Set<String> = []) throws {
        let entries = (try? fileManager.contentsOfDirectory(at: bundled, includingPropertiesForKeys: nil)) ?? []
        for directory in entries {
            let manifest = try readManifest(directory)
            if removed.contains(manifest.id) { continue }
            if !fileManager.fileExists(atPath: root.appendingPathComponent(manifest.id).path) {
                _ = try install(directory)
            }
        }
    }

    func install(_ directory: URL) throws -> LibraryPet {
        for name in ["manifest.json", "spritesheet.png"] {
            guard try directory.appendingPathComponent(name).resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw PetLibraryError.invalid("Pet files cannot be symbolic links.") }
        }
        let manifest = try readManifest(directory)
        let destination = root.appendingPathComponent(manifest.id, isDirectory: true)
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw PetLibraryError.invalid("\(manifest.name) is already in your library. Each pet needs a unique ID.")
        }
        let staging = root.appendingPathComponent(".import-" + UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }
        for name in ["manifest.json", "spritesheet.png"] {
            let source = directory.appendingPathComponent(name)
            guard try source.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw PetLibraryError.invalid("Pet files cannot be symbolic links.") }
            try fileManager.copyItem(at: source, to: staging.appendingPathComponent(name))
        }
        // Validate our own snapshot, so a changing source cannot bypass validation.
        guard try readManifest(staging) == manifest else { throw PetLibraryError.invalid("Pet metadata changed during import. Try again.") }
        _ = try SpriteAtlas(manifest: manifest, directory: staging)
        try fileManager.moveItem(at: staging, to: destination)
        return LibraryPet(manifest: manifest, directory: destination)
    }

    func importFile(_ url: URL) throws -> LibraryPet {
        if url.pathExtension.lowercased() == "png" {
            let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: directory) }
            try fileManager.copyItem(at: url, to: directory.appendingPathComponent("spritesheet.png"))
            let image = try SpriteAtlas.readImage(directory.appendingPathComponent("spritesheet.png"))
            let manifest = PetManifest(id: UUID().uuidString.lowercased(), name: String(url.deletingPathExtension().lastPathComponent.prefix(60)),
                description: "Imported sprite sheet", spriteVersion: image.height == 1872 ? 1 : 2)
            try Self.write(manifest, to: directory)
            return try install(directory)
        }
        let temporary = try PetArchive.unpack(url)
        defer { try? fileManager.removeItem(at: temporary) }
        return try install(temporary)
    }

    func rename(_ pet: LibraryPet, to name: String) throws {
        var manifest = pet.manifest; manifest.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        try manifest.validate(); try Self.write(manifest, to: pet.directory)
    }

    static func write(_ manifest: PetManifest, to folder: URL) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(to: folder.appendingPathComponent("manifest.json"), options: .atomic)
    }
}

/// Only the two required data files and an optional preview are accepted. No archive extraction runs.
enum PetArchive {
    struct Entry { let name: String; let size: Int }
    static let allowed = Set(["manifest.json", "spritesheet.png", "preview.png"])

    static func inspect(_ data: Data) throws -> [Entry] {
        guard data.count >= 22, data.count <= 25 * 1024 * 1024 else { throw PetLibraryError.invalid("Pet packs must be ZIP files under 25 MB.") }
        func u16(_ offset: Int) -> Int { Int(data[offset]) | Int(data[offset + 1]) << 8 }
        func u32(_ offset: Int) -> UInt32 { UInt32(data[offset]) | UInt32(data[offset + 1]) << 8 | UInt32(data[offset + 2]) << 16 | UInt32(data[offset + 3]) << 24 }
        var end: Int?
        for index in stride(from: data.count - 22, through: max(0, data.count - 65_557), by: -1) {
            if u32(index) == 0x06054b50, index + 22 + u16(index + 20) == data.count { end = index; break }
        }
        guard let end = end, u16(end + 4) == 0, u16(end + 6) == 0,
              u16(end + 8) == u16(end + 10), (2...3).contains(u16(end + 10)) else { throw PetLibraryError.invalid("Use a flat .petpack containing manifest.json and spritesheet.png, with an optional preview.png.") }
        let centralStart = Int(u32(end + 16)), centralSize = Int(u32(end + 12))
        guard centralStart >= 0, centralStart + centralSize == end else { throw PetLibraryError.invalid("Invalid ZIP directory.") }
        var offset = centralStart, entries: [Entry] = [], seen = Set<String>()
        for _ in 0..<u16(end + 10) {
            guard offset + 46 <= end, u32(offset) == 0x02014b50 else { throw PetLibraryError.invalid("Invalid ZIP entry.") }
            let nameSize = u16(offset + 28), extraSize = u16(offset + 30), commentSize = u16(offset + 32)
            let next = offset + 46 + nameSize + extraSize + commentSize
            guard next <= end, let name = String(data: data[(offset + 46)..<(offset + 46 + nameSize)], encoding: .utf8),
                  allowed.contains(name), seen.insert(name).inserted, u16(offset + 34) == 0,
                  u16(offset + 8) & 1 == 0, [0, 8].contains(u16(offset + 10)),
                  (u32(offset + 38) >> 16) & 0o170000 != 0o120000 else {
                throw PetLibraryError.invalid("Pet packs may contain only plain manifest.json, spritesheet.png and preview.png files. Nested paths, duplicates, links and encryption are not supported.")
            }
            let size = Int(u32(offset + 24)), maxSize = name == "manifest.json" ? 65_536 : 20 * 1024 * 1024
            guard size > 0, size <= maxSize else { throw PetLibraryError.invalid("A pet-pack file exceeds the size limit.") }
            entries.append(Entry(name: name, size: size)); offset = next
        }
        guard offset == end, seen.contains("manifest.json"), seen.contains("spritesheet.png") else { throw PetLibraryError.invalid("Missing manifest.json or spritesheet.png.") }
        return entries
    }

    static func unpack(_ url: URL) throws -> URL {
        guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 25 * 1024 * 1024 else { throw PetLibraryError.invalid("The pet pack exceeds 25 MB.") }
        let entries = try inspect(Data(contentsOf: url))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("pet-import-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            for entry in entries {
                let process = Process(), pipe = Pipe()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                process.arguments = ["-p", url.path, entry.name]
                process.standardOutput = pipe; process.standardError = FileHandle.nullDevice
                try process.run()
                DispatchQueue.global().asyncAfter(deadline: .now() + 10) { if process.isRunning { process.terminate() } }
                var content = Data()
                while let chunk = try pipe.fileHandleForReading.read(upToCount: 65_536), !chunk.isEmpty {
                    guard content.count + chunk.count <= entry.size else {
                        process.terminate(); throw PetLibraryError.invalid("Archive data exceeds its declared size.")
                    }
                    content.append(chunk)
                }
                process.waitUntilExit()
                guard process.terminationStatus == 0, content.count == entry.size else { throw PetLibraryError.invalid("The pet pack is damaged or couldn't be read.") }
                try content.write(to: folder.appendingPathComponent(entry.name))
            }
            return folder
        } catch { try? FileManager.default.removeItem(at: folder); throw error }
    }

    static func export(_ pet: LibraryPet, to destination: URL) throws {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let archive = scratch.appendingPathComponent("pet.zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = pet.directory
        process.arguments = ["-q", archive.path, "manifest.json", "spritesheet.png"]
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw PetLibraryError.invalid("The pet couldn't be exported.") }
        let bytes = try Data(contentsOf: archive)
        _ = try inspect(bytes)
        try bytes.write(to: destination, options: .atomic)
    }
}
