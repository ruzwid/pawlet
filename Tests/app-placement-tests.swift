import AppKit

enum AppPlacementTests {
    static func run() throws {
        let selfID = "com.ruzwid.pawlet"
        try ProjectTests.require(!AppPlacement.isTrackable(bundleID: nil, selfBundleID: selfID), "Nil bundle must not be trackable")
        try ProjectTests.require(!AppPlacement.isTrackable(bundleID: "", selfBundleID: selfID), "Empty bundle must not be trackable")
        try ProjectTests.require(!AppPlacement.isTrackable(bundleID: selfID, selfBundleID: selfID), "Pawlet must not be a placement slot")
        try ProjectTests.require(!AppPlacement.isTrackable(bundleID: "a/b", selfBundleID: selfID), "Slash must not be trackable")
        try ProjectTests.require(AppPlacement.isTrackable(bundleID: "com.google.Chrome", selfBundleID: selfID), "Chrome bundle must be trackable")

        let suite = "com.ruzwid.pawlet.placement-tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let origin = NSPoint(x: 40, y: 80)
        AppPlacement.writeGlobalOrigin(defaults: defaults, petID: "mochi-sample", origin: origin)
        AppPlacement.writeAppOrigin(defaults: defaults, petID: "mochi-sample", origin: origin,
            bundleID: "com.google.Chrome", selfBundleID: selfID)
        try ProjectTests.require(AppPlacement.rememberedOrigin(defaults: defaults, petID: "mochi-sample", bundleID: "com.google.Chrome") == origin,
            "Trackable write must round-trip the app origin")
        try ProjectTests.require(defaults.object(forKey: "pet.mochi-sample.x") as? Double == 40
            && defaults.object(forKey: "pet.mochi-sample.y") as? Double == 80, "Write must keep global keys")

        let other = "com.ruzwid.pawlet.placement-tests-other." + UUID().uuidString
        let onlyGlobal = UserDefaults(suiteName: other)!
        defer { onlyGlobal.removePersistentDomain(forName: other) }
        AppPlacement.writeGlobalOrigin(defaults: onlyGlobal, petID: "mochi-sample", origin: NSPoint(x: 1, y: 2))
        try ProjectTests.require(AppPlacement.rememberedOrigin(defaults: onlyGlobal, petID: "mochi-sample", bundleID: "com.google.Chrome") == nil,
            "Global-only write must not create an app slot")
        AppPlacement.writeAppOrigin(defaults: onlyGlobal, petID: "mochi-sample", origin: NSPoint(x: 3, y: 4),
            bundleID: selfID, selfBundleID: selfID)
        try ProjectTests.require(onlyGlobal.object(forKey: "pet.mochi-sample.app.\(selfID).x") == nil,
            "Pawlet bundle must not write an app slot")

        let incomplete = "com.ruzwid.pawlet.placement-tests-incomplete." + UUID().uuidString
        let hole = UserDefaults(suiteName: incomplete)!
        defer { hole.removePersistentDomain(forName: incomplete) }
        hole.set(10.0, forKey: "pet.mochi-sample.app.com.google.Chrome.x")
        try ProjectTests.require(AppPlacement.rememberedOrigin(defaults: hole, petID: "mochi-sample", bundleID: "com.google.Chrome") == nil,
            "A lone X coordinate must not restore")

        defaults.set(0.4, forKey: "pet.mochi-sample.size")
        AppPlacement.writeSizeInActiveSlot(defaults: defaults, petID: "mochi-sample", size: 0.5,
            appBundleID: "com.google.Chrome", selfBundleID: selfID)
        try ProjectTests.require(AppPlacement.rememberedSize(defaults: defaults, petID: "mochi-sample", bundleID: "com.google.Chrome") == 0.5,
            "Trackable size must round-trip")
        try ProjectTests.require((defaults.object(forKey: "pet.mochi-sample.size") as? Double) == 0.4,
            "App size write must not replace the pet-level size")
        AppPlacement.writeSizeInActiveSlot(defaults: defaults, petID: "mochi-sample", size: 9,
            appBundleID: "com.google.Chrome", selfBundleID: selfID)
        try ProjectTests.require(AppPlacement.rememberedSize(defaults: defaults, petID: "mochi-sample", bundleID: "com.google.Chrome") == MotionConstants.MAX_PET_SCALE,
            "App size must clamp at 175 percent")
        try ProjectTests.require(AppPlacement.resolvedSize(defaults: defaults, petID: "mochi-sample", settingsSize: 1.0,
            rememberPlacePerApp: true, appBundleID: "com.google.Chrome", selfBundleID: selfID) == MotionConstants.MAX_PET_SCALE,
            "Resolved size must prefer the app slot when the setting is on")
        try ProjectTests.require(AppPlacement.resolvedSize(defaults: defaults, petID: "mochi-sample", settingsSize: 1.0,
            rememberPlacePerApp: false, appBundleID: "com.google.Chrome", selfBundleID: selfID) == 0.4,
            "Resolved size must ignore app slots when the setting is off")
        try ProjectTests.require(AppPlacement.resolvedSize(defaults: defaults, petID: "mochi-sample", settingsSize: 1.0,
            rememberPlacePerApp: true, appBundleID: "com.tinyspeck.slackmacgap", selfBundleID: selfID) == 0.4,
            "Missing app size must fall back to pet-level size")
        AppPlacement.clearSizeInActiveSlot(defaults: defaults, petID: "mochi-sample",
            appBundleID: "com.google.Chrome", selfBundleID: selfID)
        try ProjectTests.require(AppPlacement.rememberedSize(defaults: defaults, petID: "mochi-sample", bundleID: "com.google.Chrome") == nil
            && (defaults.object(forKey: "pet.mochi-sample.size") as? Double) == 0.4,
            "Clearing app size must leave the pet-level size")
        AppPlacement.clearSizeInActiveSlot(defaults: defaults, petID: "mochi-sample", appBundleID: nil, selfBundleID: selfID)
        try ProjectTests.require(defaults.object(forKey: "pet.mochi-sample.size") == nil,
            "Clearing with no trackable app must remove pet-level size")
    }
}
