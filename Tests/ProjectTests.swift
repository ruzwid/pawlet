import AppKit

enum ProjectTests {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw PetLibraryError.invalid(message) }
    }
    static func reject(_ description: String, _ action: () throws -> Void) throws {
        do { try action() } catch { return }
        throw PetLibraryError.invalid("Accepted invalid input: " + description)
    }
    static func run() throws {
        let resources = Bundle.main.resourceURL!
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("pet-tests-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let library = try PetLibrary(root: scratch.appendingPathComponent("library"))
        try library.seed(from: resources.appendingPathComponent("Pets"))
        let original = library.list()[0]
        let atlas = try SpriteAtlas(manifest: original.manifest, directory: original.directory)
        try require(atlas.populatedCount == 73 && atlas.hasLookDirections, "v2 artwork count")
        try require(atlas.hash == original.manifest.artworkSHA256, "Original artwork hash")
        try require(!atlas.isOpaque(SpriteFrame(row: 0, column: 0), x: 0, topY: 0), "Transparent hit zone")
        try require(atlas.isOpaque(SpriteFrame(row: 0, column: 0), x: 96, topY: 120), "Visible hit zone")
        for state in PetState.allCases {
            let engine = AnimationEngine(); engine.perform(state, now: 100); _ = engine.frame(now: 100)
            for index in 0..<state.count {
                let frame = engine.frame(now: 100 + (Double(index) + 0.25) * state.secondsPerFrame)
                try require(frame == SpriteFrame(row: state.row, column: index), "Clock \(state.rawValue) \(index)")
            }
        }
        for index in 0..<16 {
            let radians = Double(index) * Double.pi / 8
            try require(Gaze.index(dx: sin(radians), dy: cos(radians)) == index, "Gaze direction \(index)")
        }
        let engine = AnimationEngine()
        let start = engine.frame(now: 1, animateIdle: false)
        try require(engine.frame(now: 100, animateIdle: false) == start, "Quiet idle animates")
        engine.perform(.working, now: 100); _ = engine.frame(now: 100, loopActivities: false)
        try require(engine.frame(now: 110, loopActivities: false).column == 5, "Activity should settle")
        engine.perform(.waving, now: 110)
        try require(engine.frame(now: 110).row == 3 && engine.frame(now: 112).row == 7, "Restore prior activity")
        engine.perform(.jumping, now: 200, speed: 0.5); _ = engine.frame(now: 200, speed: 0.5)
        try require(engine.frame(now: 201.2, speed: 0.5).row == 4, "Slow jump expires too early")
        try require(engine.frame(now: 201.5, speed: 0.5).row == 7, "Slow jump doesn't settle")
        engine.reset()
        try require(engine.frame(now: 300, drag: .runningRight, paused: true).column == 0, "Paused drag")
        try require(engine.frame(now: 301, gaze: SpriteFrame(row: 10, column: 4), reducedMotion: true).row == 0, "Reduced motion")
        let pack = scratch.appendingPathComponent("roundtrip.petpack")
        try PetArchive.export(original, to: pack)
        let exported = try PetArchive.unpack(pack)
        defer { try? FileManager.default.removeItem(at: exported) }
        let exportedManifest = try library.readManifest(exported)
        try require(exportedManifest == original.manifest, "Pack metadata changed")
        let exportedBytes = try Data(contentsOf: exported.appendingPathComponent("spritesheet.png"))
        let originalBytes = try Data(contentsOf: original.directory.appendingPathComponent("spritesheet.png"))
        try require(exportedBytes == originalBytes, "Pack artwork changed")
        try reject("duplicate import") { _ = try library.install(exported) }
        var newManifest = exportedManifest; newManifest.id = "third-pet-test"; newManifest.name = "Something completely new"
        try PetLibrary.write(newManifest, to: exported)
        let added = try library.install(exported)
        try require(library.list().count == 2 && added.id == "third-pet-test", "Dynamic pet import")
        try library.rename(added, to: "A new name")
        try require(library.list().contains { $0.manifest.name == "A new name" }, "Rename persistence")
        var badManifest = newManifest; badManifest.atlas = "../outside.png"
        try reject("atlas path traversal") { try badManifest.validate() }
        badManifest = newManifest; badManifest.id = "../../outside"
        try reject("pet ID path traversal") { try badManifest.validate() }
        let archiveData = try Data(contentsOf: pack)
        try reject("truncated archive") { _ = try PetArchive.inspect(archiveData.prefix(80)) }
        var unknown = archiveData
        let bytes = Array("manifest.json".utf8), replacement = Array("../evil_.json".utf8)
        if let range = unknown.range(of: Data(bytes), options: .backwards) { unknown.replaceSubrange(range, with: replacement) }
        try reject("archive path traversal") { _ = try PetArchive.inspect(unknown) }
        var badVersion = newManifest; badVersion.spriteVersion = 9
        try reject("future schema") { try badVersion.validate() }
        let target = StateCommand.parse(URL(string: "desktoppets://state?pet=third-pet-test&state=waiting&seconds=8")!)
        try require(target?.pet == "third-pet-test" && target?.state == .waiting, "Dynamic command target")
        try require(StateCommand.parse(URL(string: "desktoppets://state?state=idle&seconds=nan")!) == nil, "Non-finite duration")
        let handoff = try CreationHandoff.prepare(name: "A & B", idea: "A tiny robot + plant", style: "plush", reference: nil,
            resources: resources, workspaces: scratch.appendingPathComponent("workspaces"))
        let params = URLComponents(url: handoff.url, resolvingAgainstBaseURL: false)?.queryItems
        try require(handoff.url.scheme == "codex" && handoff.url.host == "new", "Codex deep link")
        try require(params?.first(where: { $0.name == "prompt" })?.value == handoff.prompt, "Prompt encoding")
        try require(!handoff.url.absoluteString.contains("+") && handoff.url.absoluteString.contains("%2B"), "Plus signs must survive browser query decoding")
        try require(FileManager.default.fileExists(atPath: handoff.workspace.appendingPathComponent(".agents/skills/create-desktop-pet/SKILL.md").path), "Skill isn't in creation workspace")
        let report: [String: Any] = ["ok": true, "checks": ["exact sample hash", "73 populated cells", "transparent hit zones",
            "all nine animation clocks", "sixteen cursor directions", "calm idle", "non-looping activities", "speed-aware transient lifetime",
            "pause and reduced motion", "pet-pack roundtrip preserves bytes", "arbitrary third pet", "rename persistence",
            "duplicate import rejected", "path traversal rejected", "truncated archive rejected", "schema validation",
            "dynamic command targets", "Codex prompt encoding", "creation skill bundled"]]
        print(String(data: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
    }
}
