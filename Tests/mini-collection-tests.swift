import Foundation

enum MiniCollectionTests {
    static func run(sample: LibraryPet, scratch: URL) throws {
        let sourceLibrary = try PetLibrary(root: scratch.appendingPathComponent("collection-source"))
        var minis: [LibraryPet] = []
        for index in 0..<2 {
            let directory = scratch.appendingPathComponent("collection-mini-\(index)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var manifest = sample.manifest
            manifest.id = "collection-mini-\(index)"; manifest.name = "Same display name"
            try PetLibrary.write(manifest, to: directory)
            try FileManager.default.copyItem(at: sample.directory.appendingPathComponent("spritesheet.png"), to: directory.appendingPathComponent("spritesheet.png"))
            minis.append(try sourceLibrary.install(directory))
        }
        let destination = scratch.appendingPathComponent("minis.zip")
        try MiniCollectionExport.write(minis, to: destination)
        let archiveBytes = try Data(contentsOf: destination)
        let entries = try PetArchive.inspect(archiveBytes, allowCodex: true, allowCollection: true)
        try ProjectTests.require(entries.count == 6 && Set(entries.map { $0.path.split(separator: "/").first! }) == Set(minis.map { Substring($0.id) }), "Collection must contain only selected minis in independent folders")
        let importedLibrary = try PetLibrary(root: scratch.appendingPathComponent("collection-import"))
        let imported = importedLibrary.importFiles([destination])
        try ProjectTests.require(imported.failures.isEmpty && imported.imported.map { $0.id } == minis.map { $0.id }, "One ZIP must import all selected minis")
        let sourceBytes = try Data(contentsOf: sample.directory.appendingPathComponent("spritesheet.png"))
        for mini in imported.imported {
            try ProjectTests.require(mini.manifest == minis.first(where: { $0.id == mini.id })!.manifest, "Collection must preserve metadata")
            let imageBytes = try Data(contentsOf: mini.directory.appendingPathComponent("spritesheet.png"))
            try ProjectTests.require(imageBytes == sourceBytes, "Collection must preserve exact sprite bytes")
        }
        let duplicateResult = importedLibrary.importFiles([destination])
        try ProjectTests.require(duplicateResult.imported.isEmpty && duplicateResult.failures.count == 2 && importedLibrary.list().count == 2, "Collection duplicates must leave existing minis intact")
        let extracted = try PetArchive.unpackCollection(destination)
        defer { try? FileManager.default.removeItem(at: extracted) }
        let codexMini = try CodexPetTransfer.prepareFolder(extracted.appendingPathComponent(minis[0].id), fallbackID: "unused")
        defer { try? FileManager.default.removeItem(at: codexMini) }
        let codexManifest = try sourceLibrary.readManifest(codexMini)
        try ProjectTests.require(codexManifest.id == minis[0].id && codexManifest.name == minis[0].manifest.name, "Collection folders must work with Codex metadata")
        let partialLibrary = try PetLibrary(root: scratch.appendingPathComponent("collection-partial"))
        _ = try partialLibrary.install(minis[0].directory)
        let partial = partialLibrary.importFiles([destination])
        try ProjectTests.require(partial.imported.map { $0.id } == [minis[1].id] && partial.failures.count == 1, "Existing mini in collection must not prevent later import")
        let singleZIP = scratch.appendingPathComponent("one-mini.zip")
        try MiniCollectionExport.write([minis[0]], to: singleZIP)
        let singleLibrary = try PetLibrary(root: scratch.appendingPathComponent("collection-single"))
        let singleMini = try singleLibrary.importFile(singleZIP)
        try ProjectTests.require(singleMini.id == minis[0].id, "Single-mini collection must remain compatible with existing imports")
        try ProjectTests.reject("empty collection") { try MiniCollectionExport.write([], to: destination) }
        try ProjectTests.reject("duplicate collection ID") { try MiniCollectionExport.write([minis[0], minis[0]], to: destination) }
        var invalid = minis[0]; invalid.manifest.id = "../escape"
        try ProjectTests.reject("export invalid ID") { try MiniCollectionExport.write([invalid], to: destination) }
        let preservedArchive = try Data(contentsOf: destination)
        try ProjectTests.require(preservedArchive == archiveBytes, "Failed export must preserve existing destination")
        var unsafe = archiveBytes
        let originalPath = Data((minis[0].id + "/manifest.json").utf8)
        let traversalPath = Data((String(repeating: " ", count: minis[0].id.count - 2) + "../manifest.json").utf8)
        if let pathRange = unsafe.range(of: originalPath, options: .backwards) { unsafe.replaceSubrange(pathRange, with: traversalPath) }
        try ProjectTests.reject("unsafe collection path") { _ = try PetArchive.inspect(unsafe, allowCodex: true, allowCollection: true) }
        var ambiguousCase = archiveBytes
        if let pathRange = ambiguousCase.range(of: originalPath, options: .backwards) {
            ambiguousCase.replaceSubrange(pathRange, with: Data((minis[0].id.uppercased() + "/manifest.json").utf8))
        }
        try ProjectTests.reject("collection case collision") { _ = try PetArchive.inspect(ambiguousCase, allowCodex: true, allowCollection: true) }
        try ProjectTests.reject("collection count limit") { try MiniCollectionExport.write(Array(repeating: minis[0], count: TransferConstants.MAX_COLLECTION_MINIS + 1), to: destination) }
        let encrypted = scratch.appendingPathComponent("encrypted-collection.zip")
        try TransferTests.zip(entries.map { $0.path }, in: extracted, to: encrypted, flags: ["-P", "fixture-password"])
        let encryptedResult = importedLibrary.importFiles([encrypted])
        try ProjectTests.require(encryptedResult.imported.isEmpty && encryptedResult.failures.count == 1, "Encrypted collection must be rejected")
        let mixed = scratch.appendingPathComponent("mixed-collection.zip")
        try FileManager.default.copyItem(at: minis[0].directory.appendingPathComponent("manifest.json"), to: extracted.appendingPathComponent("manifest.json"))
        try FileManager.default.copyItem(at: minis[0].directory.appendingPathComponent("spritesheet.png"), to: extracted.appendingPathComponent("spritesheet.png"))
        try TransferTests.zip(entries.map { $0.path } + ["manifest.json", "spritesheet.png"], in: extracted, to: mixed)
        try ProjectTests.reject("ambiguous flat and folder collection") { _ = try PetArchive.inspect(Data(contentsOf: mixed), allowCodex: true, allowCollection: true) }
    }
}
