import Foundation

enum TransferTests {
    static func zip(_ paths: [String], in folder: URL, to archive: URL, flags: [String] = []) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = folder
        process.arguments = ["-q"] + flags + [archive.path] + paths
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run(); process.waitUntilExit()
        try ProjectTests.require(process.terminationStatus == 0, "Couldn't create transfer fixture")
    }

    static func run(sample: LibraryPet, scratch: URL) throws {
        let folder = scratch.appendingPathComponent("codex-fixture", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var metadata = CodexPetMetadata(id: "codex-fixture", displayName: "Codex companion", description: "A portable pet",
            spriteVersionNumber: 2, spritesheetPath: "spritesheet.png")
        let metadataURL = folder.appendingPathComponent("pet.json")
        try JSONEncoder().encode(metadata).write(to: metadataURL)
        let sourceBytes = try Data(contentsOf: sample.directory.appendingPathComponent("spritesheet.png"))
        try sourceBytes.write(to: folder.appendingPathComponent("spritesheet.png"))
        try Data("Transfer instructions".utf8).write(to: folder.appendingPathComponent("README.md"))
        let library = try PetLibrary(root: scratch.appendingPathComponent("transfer-library"))
        let imported = try library.importFile(folder)
        try ProjectTests.require(imported.id == "codex-fixture" && imported.manifest.name == "Codex companion", "Codex metadata import")
        let importedBytes = try Data(contentsOf: imported.directory.appendingPathComponent("spritesheet.png"))
        try ProjectTests.require(importedBytes == sourceBytes, "Codex PNG bytes changed")
        let sharedZIP = scratch.appendingPathComponent("codex-fixture.zip")
        try zip(["codex-fixture/"], in: scratch, to: sharedZIP, flags: ["-r"])
        let zipLibrary = try PetLibrary(root: scratch.appendingPathComponent("zip-library"))
        let fromZIP = try zipLibrary.importFile(sharedZIP)
        try ProjectTests.require(fromZIP.manifest == imported.manifest, "Wrapped Codex ZIP metadata")
        let flatZIP = scratch.appendingPathComponent("flat-codex.zip")
        try zip(["pet.json", "spritesheet.png"], in: folder, to: flatZIP)
        let flatLibrary = try PetLibrary(root: scratch.appendingPathComponent("flat-library"))
        _ = try flatLibrary.importFile(flatZIP)
        let metadataLibrary = try PetLibrary(root: scratch.appendingPathComponent("metadata-library"))
        _ = try metadataLibrary.importFile(metadataURL)
        let exported = scratch.appendingPathComponent("exported-codex", isDirectory: true)
        try CodexPetTransfer.export(imported, to: exported)
        let exportedMetadata = try JSONDecoder().decode(CodexPetMetadata.self, from: Data(contentsOf: exported.appendingPathComponent("pet.json")))
        try ProjectTests.require(exportedMetadata.displayName == imported.manifest.name && exportedMetadata.spriteVersionNumber == 2 && exportedMetadata.spritesheetPath == "spritesheet.png", "Codex export metadata")
        let roundtripLibrary = try PetLibrary(root: scratch.appendingPathComponent("roundtrip-library"))
        let roundtrip = try roundtripLibrary.importFile(exported)
        try ProjectTests.require(roundtrip.manifest == imported.manifest, "Codex folder roundtrip lost metadata")
        let exportedBytes = try Data(contentsOf: exported.appendingPathComponent("spritesheet.png"))
        try ProjectTests.require(exportedBytes == sourceBytes, "Codex export changed artwork")
        try ProjectTests.reject("existing Codex folder overwrite") { try CodexPetTransfer.export(imported, to: exported) }
        metadata.id = nil; metadata.displayName = nil
        try JSONEncoder().encode(metadata).write(to: metadataURL)
        let fallbackLibrary = try PetLibrary(root: scratch.appendingPathComponent("fallback-library"))
        let fallback = try fallbackLibrary.importFile(folder)
        try ProjectTests.require(fallback.id == "codex-fixture" && fallback.manifest.name == "codex-fixture", "Codex optional identity fallback")
        let anonymousZIP = scratch.appendingPathComponent("gift.zip")
        try zip(["codex-fixture/pet.json", "codex-fixture/spritesheet.png"], in: scratch, to: anonymousZIP)
        let anonymousLibrary = try PetLibrary(root: scratch.appendingPathComponent("anonymous-library"))
        let anonymousPet = try anonymousLibrary.importFile(anonymousZIP)
        try ProjectTests.require(anonymousPet.id == "codex-fixture", "Wrapped folder identity must survive a missing id")
        metadata.spritesheetPath = "../spritesheet.png"
        try JSONEncoder().encode(metadata).write(to: metadataURL)
        try ProjectTests.reject("Codex image traversal") { _ = try library.importFile(folder) }
        metadata.spritesheetPath = "spritesheet.png"
        try JSONEncoder().encode(metadata).write(to: metadataURL)
        try FileManager.default.removeItem(at: folder.appendingPathComponent("spritesheet.png"))
        try FileManager.default.createSymbolicLink(at: folder.appendingPathComponent("spritesheet.png"), withDestinationURL: sample.directory.appendingPathComponent("spritesheet.png"))
        try ProjectTests.reject("Codex image link") { _ = try library.importFile(folder) }
        let linkedZIP = scratch.appendingPathComponent("linked-codex.zip")
        try zip(["pet.json", "spritesheet.png"], in: folder, to: linkedZIP, flags: ["-y"])
        try ProjectTests.reject("Codex archive link") { _ = try library.importFile(linkedZIP) }
        try FileManager.default.removeItem(at: folder.appendingPathComponent("spritesheet.png"))
        try sourceBytes.write(to: folder.appendingPathComponent("spritesheet.png"))
        let encryptedZIP = scratch.appendingPathComponent("encrypted.zip")
        try zip(["pet.json", "spritesheet.png"], in: folder, to: encryptedZIP, flags: ["-P", "fixture-password"])
        try ProjectTests.reject("encrypted Codex archive") { _ = try library.importFile(encryptedZIP) }
        try Data("untrusted code".utf8).write(to: folder.appendingPathComponent("run.sh"))
        let codeZIP = scratch.appendingPathComponent("code.zip")
        try zip(["pet.json", "spritesheet.png", "run.sh"], in: folder, to: codeZIP)
        try ProjectTests.reject("extra executable in Codex ZIP") { _ = try library.importFile(codeZIP) }
        let multipleZIP = scratch.appendingPathComponent("multiple.zip")
        try zip(["codex-fixture/pet.json", "codex-fixture/spritesheet.png", "exported-codex/pet.json", "exported-codex/spritesheet.png"], in: scratch, to: multipleZIP)
        try ProjectTests.reject("multiple pets in one ZIP") { _ = try library.importFile(multipleZIP) }
    }

    static func verify(_ paths: [String]) throws {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("pawlet-verify-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        for (index, path) in paths.enumerated() {
            let library = try PetLibrary(root: scratch.appendingPathComponent(String(index)))
            let imported = try library.importFile(URL(fileURLWithPath: path))
            let atlas = try SpriteAtlas(manifest: imported.manifest, directory: imported.directory)
            print("Verified \(imported.manifest.name): \(atlas.populatedCount) poses, sprite v\(imported.manifest.spriteVersion), artwork \(atlas.hash)")
        }
    }
}
