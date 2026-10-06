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
        let seeded = library.list()
        try require(Set(seeded.map { $0.id }) == Set(["mochi-sample", "paris"]), "Default library must include Mochi and Paris")
        try library.seed(from: resources.appendingPathComponent("Pets"))
        try require(library.list().count == seeded.count, "Seeding must not duplicate existing minis")
        let excluded = try PetLibrary(root: scratch.appendingPathComponent("excluded-library"))
        try excluded.seed(from: resources.appendingPathComponent("Pets"), excluding: ["paris"])
        try require(!excluded.list().contains { $0.id == "paris" }, "Removed defaults must stay removed")
        for entry in seeded { _ = try SpriteAtlas(manifest: entry.manifest, directory: entry.directory) }
        let original = seeded.first { $0.id == "mochi-sample" }!
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
        let intervalEngine = AnimationEngine()
        _ = intervalEngine.frame(now: 0, animationInterval: 10)
        try require(intervalEngine.frame(now: 0.4, animationInterval: 10).column == 1, "Idle must play before resting")
        try require(intervalEngine.frame(now: 2.2, animationInterval: 10).column == 0, "Idle must rest between loops")
        try require(intervalEngine.frame(now: 11, animationInterval: 10).column == 0, "Interval was shortened")
        try require(intervalEngine.frame(now: 12.08, animationInterval: 10).column == 1, "Idle must resume after interval")
        intervalEngine.perform(.working, now: 20)
        _ = intervalEngine.frame(now: 20, animationInterval: 10)
        try require(intervalEngine.frame(now: 22, animationInterval: 10).column == 5, "Activity rest must hold its final pose")
        try require(intervalEngine.frame(now: 30.85, animationInterval: 10).column == 0, "Activity must resume after rest")
        intervalEngine.reset()
        _ = intervalEngine.frame(now: 40, animationInterval: 0)
        try require(intervalEngine.frame(now: 42.08, animationInterval: 0).column == 1, "Zero interval must loop continuously")
        intervalEngine.perform(.waving, now: 50)
        _ = intervalEngine.frame(now: 50, animationInterval: 60)
        try require(intervalEngine.frame(now: 50.3, animationInterval: 60).column == 2, "Rest interval must not delay greetings")
        intervalEngine.reset()
        _ = intervalEngine.frame(now: 60, speed: 0.5, animationInterval: 10)
        try require(intervalEngine.frame(now: 73, speed: 0.5, animationInterval: 10).column == 0, "Rest duration must not scale with playback speed")
        try require(intervalEngine.frame(now: 73.94, speed: 0.5, animationInterval: 10).column == 1, "Slow playback must resume after the same real-time interval")
        var greeting = HoverGreeting()
        try require(greeting.shouldGreet(isHovering: true, isEnabled: true, isBlocked: false), "Hover entry must greet")
        try require(!greeting.shouldGreet(isHovering: true, isEnabled: true, isBlocked: false), "Stationary pointer must not repeat greeting")
        _ = greeting.shouldGreet(isHovering: false, isEnabled: true, isBlocked: false)
        try require(greeting.shouldGreet(isHovering: true, isEnabled: true, isBlocked: false), "Re-entry must greet without a cooldown")
        _ = greeting.shouldGreet(isHovering: false, isEnabled: true, isBlocked: false)
        try require(!greeting.shouldGreet(isHovering: true, isEnabled: true, isBlocked: true), "Pause and Reduce Motion must block greeting")
        try require(!greeting.shouldGreet(isHovering: true, isEnabled: true, isBlocked: false), "Unblocking under a stationary pointer must not greet")
        var disabledGreeting = HoverGreeting()
        try require(!disabledGreeting.shouldGreet(isHovering: true, isEnabled: false, isBlocked: false), "Disabled hover must stay still")
        let previousSettings = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"animateIdle":true,"size":1.25,"followCursor":false}"#.utf8))
        try require(previousSettings.animateIdle && previousSettings.size == 1.25 && previousSettings.animationInterval == 10 && previousSettings.greetOnHover, "Settings upgrade must preserve prior choices and add new defaults")
        let smallSettings = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"size":0.25}"#.utf8))
        try require(smallSettings.size == 0.25, "25 percent size must survive persistence")
        let outOfRangeSettings = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"size":0.1}"#.utf8))
        try require(outOfRangeSettings.size == MotionConstants.MIN_PET_SCALE, "Pet size must clamp at 25 percent")
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
        try require(library.list().count == seeded.count + 1 && added.id == "third-pet-test", "Dynamic pet import")
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
        let target = StateCommand.parse(URL(string: "pawlet://state?pet=third-pet-test&state=waiting&seconds=8")!)
        try require(target?.pet == "third-pet-test" && target?.state == .waiting, "Dynamic command target")
        try require(StateCommand.parse(URL(string: "pawlet://state?state=idle&seconds=nan")!) == nil, "Non-finite duration")
        let handoff = try CreationHandoff.prepare(name: "A & B", idea: "A tiny robot + plant", style: "plush", reference: nil,
            resources: resources, workspaces: scratch.appendingPathComponent("workspaces"))
        let params = URLComponents(url: handoff.url, resolvingAgainstBaseURL: false)?.queryItems
        try require(handoff.url.scheme == "codex" && handoff.url.host == "new", "Codex deep link")
        try require(params?.first(where: { $0.name == "prompt" })?.value == handoff.prompt, "Prompt encoding")
        try require(!handoff.url.absoluteString.contains("+") && handoff.url.absoluteString.contains("%2B"), "Plus signs must survive browser query decoding")
        try require(FileManager.default.fileExists(atPath: handoff.workspace.appendingPathComponent(".agents/skills/create-desktop-pet/SKILL.md").path), "Skill isn't in creation workspace")
        let automaticStyle = try CreationHandoff.prepare(name: "Robot", idea: "A tiny robot", style: "choose-for-me", reference: nil,
            resources: resources, workspaces: scratch.appendingPathComponent("workspaces"))
        try require(automaticStyle.prompt.contains("Choose a cohesive, cute visual style") && !automaticStyle.prompt.contains("Use the requested visual style"), "Choose for me must delegate a consistent style choice")
        try require(handoff.prompt.contains("Use the requested visual style: plush"), "Explicit style must be preserved")
        try MiniCustomizationTests.run(sample: original, scratch: scratch)
        try TransferTests.run(sample: original, scratch: scratch)
        try AtlasCompatibilityTests.run(sample: original, scratch: scratch)
        try InteractionPreviewTests.run(sample: original)
        let report: [String: Any] = ["ok": true, "checks": ["exact sample hash", "73 populated cells", "transparent hit zones",
            "all nine animation clocks", "sixteen cursor directions", "calm idle", "non-looping activities", "speed-aware transient lifetime",
            "pause and reduced motion", "pet-pack roundtrip preserves bytes", "arbitrary third pet", "rename persistence",
            "duplicate import rejected", "path traversal rejected", "truncated archive rejected", "schema validation",
            "dynamic command targets", "Codex prompt encoding", "creation skill bundled", "idle and activity rest intervals",
            "zero interval and playback speed", "immediate hover re-entry", "blocked and disabled hover", "settings upgrade", "25 percent size persistence", "automatic and explicit artwork styles", "Codex folder and ZIP imports", "Codex export roundtrip", "unsafe Codex transfers rejected", "Finder ZIP metadata ignored", "unused frames ignored without changing bytes", "missing required frames rejected", "all hover reactions restore idle", "hover reaction persistence", "preview looping and speed", "v1 and v2 preview choices", "frame stepping and reduced motion", "distinct artwork selection switches", "shared preview crop preserves pose registration", "Paris and Mochi defaults", "removed defaults stay removed", "batch import continues after failures", "per-mini size persistence and fallback"]]
        print(String(data: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
    }
}
