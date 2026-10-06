import AppKit

enum MiniCustomizationTests {
    static func run(sample: LibraryPet, scratch: URL) throws {
        let library = try PetLibrary(root: scratch.appendingPathComponent("batch-library"))
        var sources: [URL] = []
        for index in 0..<2 {
            let source = scratch.appendingPathComponent("batch-source-\(index)")
            try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
            var manifest = sample.manifest; manifest.id = "batch-mini-\(index)"
            try PetLibrary.write(manifest, to: source)
            try FileManager.default.copyItem(at: sample.directory.appendingPathComponent("spritesheet.png"), to: source.appendingPathComponent("spritesheet.png"))
            let pack = scratch.appendingPathComponent("batch-mini-\(index).petpack")
            try PetArchive.export(LibraryPet(manifest: manifest, directory: source), to: pack)
            sources.append(pack)
        }
        let broken = scratch.appendingPathComponent("broken.zip")
        try Data("invalid archive".utf8).write(to: broken)
        let result = library.importFiles([sources[0], broken, sources[1], sources[0]])
        try ProjectTests.require(result.imported.map { $0.id } == ["batch-mini-0", "batch-mini-1"] && result.failures.count == 2,
            "A failed or duplicate mini must not stop later imports")
        try ProjectTests.require(result.failures[0].contains("broken.zip") && result.failures[1].contains("batch-mini-0.petpack"), "Batch failures must identify their source")
        try ProjectTests.require(library.list().count == 2, "Duplicate import must not create another mini")
        let originalArtwork = try Data(contentsOf: sample.directory.appendingPathComponent("spritesheet.png"))
        for entry in library.list() {
            let importedArtwork = try Data(contentsOf: entry.directory.appendingPathComponent("spritesheet.png"))
            try ProjectTests.require(importedArtwork == originalArtwork, "Batch import must preserve artwork")
        }
        let suite = "com.ruzwid.pawlet.size-tests." + UUID().uuidString
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        let app = AppDelegate(defaults: preferences)
        app.settings.size = 0.75
        app.setSizeOverride(0.3, for: "one")
        app.settings.size = 1.25
        try ProjectTests.require(app.miniSize(for: "one") == 0.3 && app.miniSize(for: "two") == 1.25, "Default size must only affect minis without overrides")
        let reopened = AppDelegate(defaults: UserDefaults(suiteName: suite)!)
        try ProjectTests.require(reopened.sizeOverride(for: "one") == 0.3, "Individual size must survive relaunch")
        app.setSizeOverride(.nan, for: "one")
        try ProjectTests.require(app.miniSize(for: "one") == 0.3, "Invalid size must not replace the saved override")
        app.setSizeOverride(0.1, for: "one")
        try ProjectTests.require(app.miniSize(for: "one") == MotionConstants.MIN_PET_SCALE, "Individual size must clamp at 25 percent")
        app.setSizeOverride(3, for: "one")
        try ProjectTests.require(app.miniSize(for: "one") == MotionConstants.MAX_PET_SCALE, "Individual size must clamp at 175 percent")
        app.setSizeOverride(nil, for: "one")
        try ProjectTests.require(app.sizeOverride(for: "one") == nil && app.miniSize(for: "one") == 1.25, "Reset must follow the current default size")
    }
}
