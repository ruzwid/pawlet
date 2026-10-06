import AppKit

enum AppPlacement {
    static func isTrackable(bundleID: String?, selfBundleID: String?) -> Bool {
        guard let bundleID, bundleID.range(of: "^[A-Za-z0-9][A-Za-z0-9._-]{0,253}$", options: .regularExpression) != nil else { return false }
        if let selfBundleID, bundleID == selfBundleID { return false }
        return true
    }

    /// Always updates `pet.<id>.x` / `.y`. Does not touch per-app keys.
    static func writeGlobalOrigin(defaults: UserDefaults, petID: String, origin: NSPoint) {
        defaults.set(Double(origin.x), forKey: "pet.\(petID).x")
        defaults.set(Double(origin.y), forKey: "pet.\(petID).y")
    }

    /// Updates only `pet.<id>.app.<bundle>.x` / `.y` when the bundle is trackable.
    static func writeAppOrigin(defaults: UserDefaults, petID: String, origin: NSPoint, bundleID: String, selfBundleID: String?) {
        guard isTrackable(bundleID: bundleID, selfBundleID: selfBundleID) else { return }
        defaults.set(Double(origin.x), forKey: "pet.\(petID).app.\(bundleID).x")
        defaults.set(Double(origin.y), forKey: "pet.\(petID).app.\(bundleID).y")
    }

    static func rememberedOrigin(defaults: UserDefaults, petID: String, bundleID: String) -> NSPoint? {
        let xKey = "pet.\(petID).app.\(bundleID).x"
        let yKey = "pet.\(petID).app.\(bundleID).y"
        guard defaults.object(forKey: xKey) != nil, defaults.object(forKey: yKey) != nil else { return nil }
        return NSPoint(x: defaults.double(forKey: xKey), y: defaults.double(forKey: yKey))
    }

    static func clampSize(_ size: Double) -> Double {
        min(MotionConstants.MAX_PET_SCALE, max(MotionConstants.MIN_PET_SCALE, size))
    }

    /// Writes exactly one size slot: the app key when trackable, otherwise `pet.<id>.size`.
    static func writeSizeInActiveSlot(defaults: UserDefaults, petID: String, size: Double, appBundleID: String?, selfBundleID: String?) {
        guard size.isFinite else { return }
        let value = clampSize(size)
        if let appBundleID, isTrackable(bundleID: appBundleID, selfBundleID: selfBundleID) {
            defaults.set(value, forKey: "pet.\(petID).app.\(appBundleID).size")
        } else {
            defaults.set(value, forKey: "pet.\(petID).size")
        }
    }

    static func rememberedSize(defaults: UserDefaults, petID: String, bundleID: String) -> Double? {
        let key = "pet.\(petID).app.\(bundleID).size"
        guard let number = defaults.object(forKey: key) as? NSNumber, number.doubleValue.isFinite else { return nil }
        return clampSize(number.doubleValue)
    }

    /// Clears exactly one size slot: the app key when trackable, otherwise `pet.<id>.size`.
    static func clearSizeInActiveSlot(defaults: UserDefaults, petID: String, appBundleID: String?, selfBundleID: String?) {
        if let appBundleID, isTrackable(bundleID: appBundleID, selfBundleID: selfBundleID) {
            defaults.removeObject(forKey: "pet.\(petID).app.\(appBundleID).size")
        } else {
            defaults.removeObject(forKey: "pet.\(petID).size")
        }
    }

    static func resolvedSize(defaults: UserDefaults, petID: String, settingsSize: Double, rememberPlacePerApp: Bool, appBundleID: String?, selfBundleID: String?) -> Double {
        if rememberPlacePerApp, let appBundleID, isTrackable(bundleID: appBundleID, selfBundleID: selfBundleID),
           let size = rememberedSize(defaults: defaults, petID: petID, bundleID: appBundleID) {
            return size
        }
        if let number = defaults.object(forKey: "pet.\(petID).size") as? NSNumber, number.doubleValue.isFinite {
            return clampSize(number.doubleValue)
        }
        return clampSize(settingsSize)
    }
}
