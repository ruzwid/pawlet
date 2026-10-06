import AppKit

struct PlacementWindowCandidate: Equatable {
    var bundleID: String
    var bounds: NSRect
    /// Front-to-back order: 0 is topmost among the provided list.
    var zOrder: Int
    var isFullscreen: Bool
}

enum AppPlacement {
    /// Prefer lowest zOrder among fullscreen candidates that intersect `monitor`;
    /// else lowest zOrder among intersecting non-fullscreen; else nil.
    static func preferredAppBundleID(
        monitor: NSRect,
        candidates: [PlacementWindowCandidate],
        selfBundleID: String?
    ) -> String? {
        let intersecting = candidates.filter { candidate in
            guard intersectionArea(monitor, candidate.bounds) > 0 else { return false }
            return isTrackable(bundleID: candidate.bundleID, selfBundleID: selfBundleID)
        }
        if let bestFS = intersecting.filter(\.isFullscreen).min(by: { $0.zOrder < $1.zOrder }) {
            return bestFS.bundleID
        }
        return intersecting.min(by: { $0.zOrder < $1.zOrder })?.bundleID
    }

    static func isTrackable(bundleID: String?, selfBundleID: String?) -> Bool {
        guard let bundleID, bundleID.range(of: "^[A-Za-z0-9][A-Za-z0-9._-]{0,253}$", options: .regularExpression) != nil else { return false }
        if let selfBundleID, bundleID == selfBundleID { return false }
        return true
    }

    /// Bottom-left origin that keeps `size` inside `safe` (AppKit coords).
    static func clampedOrigin(origin: NSPoint, size: NSSize, safe: NSRect) -> NSPoint {
        NSPoint(
            x: min(max(origin.x, safe.minX), max(safe.minX, safe.maxX - size.width)),
            y: min(max(origin.y, safe.minY), max(safe.minY, safe.maxY - size.height)))
    }

    /// True when the frame fits in `safe`, allowing `slop` points of float/edge noise.
    static func frameFitsSafeArea(_ frame: NSRect, safe: NSRect, slop: CGFloat = 0.5) -> Bool {
        let padded = safe.insetBy(dx: -slop, dy: -slop)
        return padded.contains(frame)
    }

    /// Work area that best contains `frame` (max intersection). Disconnected coords pick nearest by center.
    static func preferredSafeFrame(for frame: NSRect, candidates: [NSRect]) -> NSRect? {
        guard !candidates.isEmpty else { return nil }
        var bestArea: CGFloat = -1
        var best = candidates[0]
        for candidate in candidates {
            let area = intersectionArea(candidate, frame)
            if area > bestArea {
                bestArea = area
                best = candidate
            }
        }
        if bestArea > 0 { return best }

        let center = NSPoint(x: frame.midX, y: frame.midY)
        var bestDist = CGFloat.greatestFiniteMagnitude
        var nearest = candidates[0]
        for candidate in candidates {
            let dx = center.x - candidate.midX
            let dy = center.y - candidate.midY
            let dist = dx * dx + dy * dy
            if dist < bestDist {
                bestDist = dist
                nearest = candidate
            }
        }
        return nearest
    }

    private static func intersectionArea(_ a: NSRect, _ b: NSRect) -> CGFloat {
        let i = a.intersection(b)
        return i.isNull ? 0 : i.width * i.height
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
