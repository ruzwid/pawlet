import AppKit

enum AppPlacement {
    static func isTrackable(bundleID: String?, selfBundleID: String?) -> Bool {
        guard let bundleID, bundleID.range(of: "^[A-Za-z0-9][A-Za-z0-9._-]{0,253}$", options: .regularExpression) != nil else { return false }
        if let selfBundleID, bundleID == selfBundleID { return false }
        return true
    }

    /// Slot for an origin write: drag-start app wins over current frontmost when per-app place is on.
    static func originWriteAppBundleID(rememberPlacePerApp: Bool, dragStartBundleID: String?, currentBundleID: String?) -> String? {
        guard rememberPlacePerApp else { return nil }
        return dragStartBundleID ?? currentBundleID
    }

    static func writeOrigin(defaults: UserDefaults, petID: String, origin: NSPoint, appBundleID: String?, selfBundleID: String?) {
        defaults.set(Double(origin.x), forKey: "pet.\(petID).x")
        defaults.set(Double(origin.y), forKey: "pet.\(petID).y")
        guard let appBundleID, isTrackable(bundleID: appBundleID, selfBundleID: selfBundleID) else { return }
        defaults.set(Double(origin.x), forKey: "pet.\(petID).app.\(appBundleID).x")
        defaults.set(Double(origin.y), forKey: "pet.\(petID).app.\(appBundleID).y")
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

    static func writeSize(defaults: UserDefaults, petID: String, size: Double, appBundleID: String?, selfBundleID: String?) {
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

    static func clearSize(defaults: UserDefaults, petID: String, appBundleID: String?, selfBundleID: String?) {
        if let appBundleID, isTrackable(bundleID: appBundleID, selfBundleID: selfBundleID) {
            defaults.removeObject(forKey: "pet.\(petID).app.\(appBundleID).size")
        } else {
            defaults.removeObject(forKey: "pet.\(petID).size")
        }
    }

    static func hasSizeOverride(defaults: UserDefaults, petID: String, rememberPlacePerApp: Bool, appBundleID: String?, selfBundleID: String?) -> Bool {
        if rememberPlacePerApp, let appBundleID, isTrackable(bundleID: appBundleID, selfBundleID: selfBundleID) {
            return rememberedSize(defaults: defaults, petID: petID, bundleID: appBundleID) != nil
        }
        guard let number = defaults.object(forKey: "pet.\(petID).size") as? NSNumber, number.doubleValue.isFinite else { return false }
        return true
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

    /// True when restoring a remembered place should cross-fade (origin and/or width changed).
    static func warrantsTransition(fromOrigin: NSPoint, toOrigin: NSPoint?, fromWidth: CGFloat, toWidth: CGFloat) -> Bool {
        if let toOrigin, hypot(toOrigin.x - fromOrigin.x, toOrigin.y - fromOrigin.y) > 0.5 { return true }
        return abs(fromWidth - toWidth) > 0.5
    }
}
