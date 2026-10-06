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

        let safe = NSRect(x: 0, y: 0, width: 1000, height: 800)
        let size = NSSize(width: 192, height: 208)
        let flushTop = NSPoint(x: 10, y: safe.maxY - size.height)
        try ProjectTests.require(
            AppPlacement.clampedOrigin(origin: flushTop, size: size, safe: safe) == flushTop,
            "Flush-top origin must stay put when already inside the safe area")
        try ProjectTests.require(
            AppPlacement.frameFitsSafeArea(NSRect(origin: flushTop, size: size), safe: safe),
            "Flush-top frame must count as fitting")
        let slightlyOver = NSPoint(x: 10, y: safe.maxY - size.height + 0.25)
        try ProjectTests.require(
            AppPlacement.frameFitsSafeArea(NSRect(origin: slightlyOver, size: size), safe: safe),
            "Sub-point top overflow within slop must still count as fitting")
        let wayOver = NSPoint(x: 10, y: safe.maxY - size.height + 8)
        let clampedOver = AppPlacement.clampedOrigin(origin: wayOver, size: size, safe: safe)
        try ProjectTests.require(clampedOver.y == flushTop.y,
            "Large top overflow must clamp back to the flush-top origin")
        try ProjectTests.require(
            !AppPlacement.frameFitsSafeArea(NSRect(origin: wayOver, size: size), safe: safe),
            "Large top overflow must not count as fitting")

        let primary = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let secondary = NSRect(x: 1920, y: 0, width: 1920, height: 1080)
        let onSecondary = NSRect(x: 2500, y: 100, width: size.width, height: size.height)
        try ProjectTests.require(
            AppPlacement.preferredSafeFrame(for: onSecondary, candidates: [primary, secondary]) == secondary,
            "Preferred safe frame must pick the monitor that contains the mini")
        let onPrimary = NSRect(x: 40, y: 60, width: size.width, height: size.height)
        try ProjectTests.require(
            AppPlacement.preferredSafeFrame(for: onPrimary, candidates: [primary, secondary]) == primary,
            "Preferred safe frame must keep a primary-monitor mini on primary")
        let disconnected = NSRect(x: 5000, y: 100, width: size.width, height: size.height)
        try ProjectTests.require(
            AppPlacement.preferredSafeFrame(for: disconnected, candidates: [primary, secondary]) == secondary,
            "Disconnected-monitor coords must fall back to the nearest screen")

        let monitor = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let cursorFS = PlacementWindowCandidate(
            bundleID: "com.todesktop.230313mzl4w4u92", bounds: monitor, zOrder: 1, isFullscreen: true)
        let chromeWin = PlacementWindowCandidate(
            bundleID: "com.google.Chrome", bounds: NSRect(x: 100, y: 100, width: 800, height: 600),
            zOrder: 0, isFullscreen: false)
        try ProjectTests.require(
            AppPlacement.preferredAppBundleID(monitor: monitor, candidates: [chromeWin, cursorFS], selfBundleID: selfID)
                == "com.todesktop.230313mzl4w4u92",
            "Fullscreen on the monitor must beat a higher z-order windowed app")
        let chromeOther = PlacementWindowCandidate(
            bundleID: "com.google.Chrome", bounds: NSRect(x: 2000, y: 100, width: 800, height: 600),
            zOrder: 0, isFullscreen: true)
        try ProjectTests.require(
            AppPlacement.preferredAppBundleID(monitor: monitor, candidates: [chromeOther, cursorFS], selfBundleID: selfID)
                == "com.todesktop.230313mzl4w4u92",
            "Fullscreen on another monitor must not win")
        let slackWin = PlacementWindowCandidate(
            bundleID: "com.tinyspeck.slackmacgap", bounds: NSRect(x: 50, y: 50, width: 900, height: 700),
            zOrder: 0, isFullscreen: false)
        let cursorWin = PlacementWindowCandidate(
            bundleID: "com.todesktop.230313mzl4w4u92", bounds: NSRect(x: 200, y: 200, width: 700, height: 500),
            zOrder: 1, isFullscreen: false)
        try ProjectTests.require(
            AppPlacement.preferredAppBundleID(monitor: monitor, candidates: [slackWin, cursorWin], selfBundleID: selfID)
                == "com.tinyspeck.slackmacgap",
            "With no fullscreen, topmost intersecting window wins")
        try ProjectTests.require(
            AppPlacement.preferredAppBundleID(monitor: monitor, candidates: [chromeOther], selfBundleID: selfID) == nil,
            "No intersecting window must yield nil")
        let pawlet = PlacementWindowCandidate(
            bundleID: selfID, bounds: monitor, zOrder: 0, isFullscreen: true)
        try ProjectTests.require(
            AppPlacement.preferredAppBundleID(monitor: monitor, candidates: [pawlet, slackWin], selfBundleID: selfID)
                == "com.tinyspeck.slackmacgap",
            "Pawlet windows must never win")
    }
}
