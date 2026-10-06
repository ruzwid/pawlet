import Foundation

enum MiniCollectionExport {
    static func write(_ minis: [LibraryPet], to destination: URL) throws {
        guard !minis.isEmpty, minis.count <= TransferConstants.MAX_COLLECTION_MINIS else {
            throw PetLibraryError.invalid("Choose between 1 and \(TransferConstants.MAX_COLLECTION_MINIS) minis for each ZIP.")
        }
        guard Set(minis.map { $0.id.lowercased() }).count == minis.count else {
            throw PetLibraryError.invalid("Each exported mini must have a unique ID.")
        }
        let fileManager = FileManager.default
        let scratch = fileManager.temporaryDirectory.appendingPathComponent("pawlet-collection-" + UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: scratch) }
        var paths: [String] = []
        for mini in minis.sorted(by: { $0.id < $1.id }) {
            try mini.manifest.validate()
            try CodexPetTransfer.export(mini, to: scratch.appendingPathComponent(mini.id, isDirectory: true))
            paths.append(contentsOf: ["manifest.json", "pet.json", "spritesheet.png"].map { mini.id + "/" + $0 })
        }
        let archive = scratch.appendingPathComponent("minis.zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = scratch
        process.arguments = ["-q", archive.path] + paths
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw PetLibraryError.invalid("The minis couldn't be exported. Try another save location.") }
        guard (try archive.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= TransferConstants.MAX_COLLECTION_BYTES else {
            throw PetLibraryError.invalid("This ZIP exceeds 250 MB. Export fewer minis at a time.")
        }
        let bytes = try Data(contentsOf: archive)
        _ = try PetArchive.inspect(bytes, allowCodex: true, allowCollection: true)
        try bytes.write(to: destination, options: .atomic)
    }

    static func writeInBackground(_ minis: [LibraryPet], to destination: URL) async throws {
        try write(minis, to: destination)
    }
}
