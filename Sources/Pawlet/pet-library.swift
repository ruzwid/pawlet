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
            throw PetLibraryError.invalid("This mini uses an unsupported format. Use schemaVersion 1 and spriteVersion 1 or 2.")
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        guard !id.isEmpty, id.utf8.count <= 64, id.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw PetLibraryError.invalid("The mini ID must be 1–64 letters, numbers, hyphens or underscores.")
        }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 60,
              !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              description.count <= 600, (author?.count ?? 0) <= 100 else {
            throw PetLibraryError.invalid("The mini name or description is too long or invalid.")
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
            guard try directory.appendingPathComponent(name).resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw PetLibraryError.invalid("Mini files cannot be symbolic links.") }
        }
        let manifest = try readManifest(directory)
        let destination = root.appendingPathComponent(manifest.id, isDirectory: true)
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw PetLibraryError.invalid("\(manifest.name) is already in your library. Each mini needs a unique ID.")
        }
        let staging = root.appendingPathComponent(".import-" + UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }
        for name in ["manifest.json", "spritesheet.png"] {
            let source = directory.appendingPathComponent(name)
            guard try source.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw PetLibraryError.invalid("Mini files cannot be symbolic links.") }
            try fileManager.copyItem(at: source, to: staging.appendingPathComponent(name))
        }
        // Validate our own snapshot, so a changing source cannot bypass validation.
        guard try readManifest(staging) == manifest else { throw PetLibraryError.invalid("Mini metadata changed during import. Try again.") }
        _ = try SpriteAtlas(manifest: manifest, directory: staging)
        try fileManager.moveItem(at: staging, to: destination)
        return LibraryPet(manifest: manifest, directory: destination)
    }

    func importFiles(_ urls: [URL]) -> (imported: [LibraryPet], failures: [String]) {
        var imported: [LibraryPet] = []
        var failures: [String] = []
        for url in urls {
            do { imported.append(try importFile(url)) }
            catch { failures.append("\(url.lastPathComponent): \(error.localizedDescription)") }
        }
        return (imported, failures)
    }

    func importFile(_ url: URL) throws -> LibraryPet {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else { throw PetLibraryError.invalid("Choose a mini file or folder, rather than a symbolic link.") }
        if values.isDirectory == true { return try importFolder(url) }
        if url.lastPathComponent == "pet.json" || url.lastPathComponent == "manifest.json" {
            return try importFolder(url.deletingLastPathComponent())
        }
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
        return try importFolder(temporary, fallbackID: url.deletingPathExtension().lastPathComponent)
    }

    func importFolder(_ directory: URL, fallbackID: String? = nil) throws -> LibraryPet {
        if fileManager.fileExists(atPath: directory.appendingPathComponent("manifest.json").path) { return try install(directory) }
        guard fileManager.fileExists(atPath: directory.appendingPathComponent("pet.json").path) else {
            throw PetLibraryError.invalid("Choose the mini's own folder containing manifest.json or pet.json beside its sprite sheet. You can also import a complete spritesheet.png directly.")
        }
        let snapshot = try CodexPetTransfer.prepareFolder(directory, fallbackID: fallbackID ?? directory.lastPathComponent)
        defer { try? fileManager.removeItem(at: snapshot) }
        return try install(snapshot)
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

enum PetArchive {
    struct Entry {
        let path: String
        let size: Int
        var name: String { path.split(separator: "/").last.map(String.init) ?? path }
    }
    static let allowed = Set(["manifest.json", "spritesheet.png", "preview.png"])
    static let compatibleAllowed = allowed.union(["pet.json", "spritesheet.webp", "README.md"])

    static func isFinderMetadata(_ path: String) -> Bool {
        let isDirectory = path.hasSuffix("/")
        let components = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        let names = isDirectory ? Array(components.dropLast()) : components
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_. ")
        guard !names.isEmpty, names.count <= 3,
              names.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && $0.unicodeScalars.allSatisfy { allowedCharacters.contains($0) } }) else { return false }
        if !isDirectory, names.count <= 2, names.last == ".DS_Store" { return true }
        guard names.first == "__MACOSX" else { return false }
        return isDirectory ? names.count <= 2 : names.count >= 2 && names.last!.hasPrefix("._")
    }

    static func inspect(_ data: Data, allowCodex: Bool = false) throws -> [Entry] {
        guard data.count >= 22, data.count <= TransferConstants.MAX_ARCHIVE_BYTES else { throw PetLibraryError.invalid("Mini packs must be ZIP files under 25 MB.") }
        func u16(_ offset: Int) -> Int { Int(data[offset]) | Int(data[offset + 1]) << 8 }
        func u32(_ offset: Int) -> UInt32 { UInt32(data[offset]) | UInt32(data[offset + 1]) << 8 | UInt32(data[offset + 2]) << 16 | UInt32(data[offset + 3]) << 24 }
        var end: Int?
        for index in stride(from: data.count - 22, through: max(0, data.count - 65_557), by: -1) {
            if u32(index) == 0x06054b50, index + 22 + u16(index + 20) == data.count { end = index; break }
        }
        let entryRange = allowCodex ? 2...TransferConstants.MAX_COMPATIBLE_ZIP_ENTRIES : 2...3
        guard let end = end, u16(end + 4) == 0, u16(end + 6) == 0,
              u16(end + 8) == u16(end + 10), entryRange.contains(u16(end + 10)) else {
            throw PetLibraryError.invalid("Choose a .petpack, or a ZIP containing one mini folder with metadata and its sprite sheet.")
        }
        let centralStart = Int(u32(end + 16)), centralSize = Int(u32(end + 12))
        guard centralStart >= 0, centralStart + centralSize == end else { throw PetLibraryError.invalid("Invalid ZIP directory.") }
        var offset = centralStart, entries: [Entry] = [], seen = Set<String>(), prefixes = Set<String>(), seenPaths = Set<String>()
        let folderCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_ ")
        for _ in 0..<u16(end + 10) {
            guard offset + 46 <= end, u32(offset) == 0x02014b50 else { throw PetLibraryError.invalid("Invalid ZIP entry.") }
            let nameSize = u16(offset + 28), extraSize = u16(offset + 30), commentSize = u16(offset + 32)
            let next = offset + 46 + nameSize + extraSize + commentSize
            guard next <= end, let path = String(data: data[(offset + 46)..<(offset + 46 + nameSize)], encoding: .utf8),
                  seenPaths.insert(path).inserted, u16(offset + 34) == 0,
                  u16(offset + 8) & 1 == 0, [0, 8].contains(u16(offset + 10)) else {
                throw PetLibraryError.invalid("Duplicate paths, encryption and unsupported ZIP entries are not accepted.")
            }
            let components = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
            let isDirectory = path.hasSuffix("/")
            let mode = (u32(offset + 38) >> 16) & 0o170000
            guard mode == 0 || mode == (isDirectory ? 0o040000 : 0o100000) else { throw PetLibraryError.invalid("Archive links and special files are not supported.") }
            if allowCodex && isFinderMetadata(path) { offset = next; continue }
            let hasFolder = components.count == 2
            guard components.count == 1 || (allowCodex && hasFolder),
                  !hasFolder || (!components[0].isEmpty && components[0].unicodeScalars.allSatisfy { folderCharacters.contains($0) }),
                  !isDirectory || (allowCodex && hasFolder) else {
                throw PetLibraryError.invalid("ZIPs may contain one flat mini or one mini folder. Nested paths and multiple minis are not supported.")
            }
            let size = Int(u32(offset + 24))
            if isDirectory {
                guard size == 0 else { throw PetLibraryError.invalid("Invalid ZIP folder entry.") }
            } else {
                let name = components.last!
                guard (allowCodex ? compatibleAllowed : allowed).contains(name), seen.insert(name).inserted else {
                    throw PetLibraryError.invalid("Choose a mini ZIP containing only metadata, a sprite sheet and optional preview/README. Source and QA bundles are not mini packs.")
                }
                let maximumSize = ["manifest.json", "pet.json", "README.md"].contains(name) ? TransferConstants.MAX_METADATA_BYTES : TransferConstants.MAX_IMAGE_BYTES
                guard (size > 0 || name == "README.md"), size <= maximumSize else { throw PetLibraryError.invalid("A mini-pack file exceeds the size limit.") }
                prefixes.insert(hasFolder ? components[0] : "")
                entries.append(Entry(path: path, size: size))
            }
            offset = next
        }
        let hasManifest = seen.contains("manifest.json") && seen.contains("spritesheet.png")
        let hasCodexPet = allowCodex && seen.contains("pet.json") && (seen.contains("spritesheet.png") || seen.contains("spritesheet.webp"))
        guard offset == end, prefixes.count == 1, hasManifest || hasCodexPet,
              !(seen.contains("spritesheet.png") && seen.contains("spritesheet.webp")) else {
            throw PetLibraryError.invalid("The ZIP must contain one mini's metadata and one sprite sheet.")
        }
        return entries
    }

    static func unpack(_ url: URL) throws -> URL {
        guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 25 * 1024 * 1024 else { throw PetLibraryError.invalid("The mini pack exceeds 25 MB.") }
        let entries = try inspect(Data(contentsOf: url), allowCodex: url.pathExtension.lowercased() == "zip")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("pet-import-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            for entry in entries {
                let process = Process(), pipe = Pipe()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                process.arguments = ["-p", url.path, entry.path]
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
                guard process.terminationStatus == 0, content.count == entry.size else { throw PetLibraryError.invalid("The mini pack is damaged or couldn't be read.") }
                try content.write(to: folder.appendingPathComponent(entry.name))
            }
            let metadataURL = folder.appendingPathComponent("pet.json")
            if FileManager.default.fileExists(atPath: metadataURL.path) {
                var metadata = try JSONDecoder().decode(CodexPetMetadata.self, from: Data(contentsOf: metadataURL))
                if metadata.id == nil {
                    let wrappedFolder = entries.first?.path.split(separator: "/").dropLast().first.map(String.init)
                    metadata.id = CodexPetTransfer.localID(from: wrappedFolder ?? url.deletingPathExtension().lastPathComponent)
                    try JSONEncoder().encode(metadata).write(to: metadataURL)
                }
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
        guard process.terminationStatus == 0 else { throw PetLibraryError.invalid("The mini couldn't be exported.") }
        let bytes = try Data(contentsOf: archive)
        _ = try inspect(bytes)
        try bytes.write(to: destination, options: .atomic)
    }
}
