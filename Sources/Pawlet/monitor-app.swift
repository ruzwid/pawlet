import AppKit
import ApplicationServices

enum MonitorFrontApp {
    /// Fullscreen if window bounds cover `screen.frame` within `slop` points on each edge.
    static let fullscreenSlop: CGFloat = 2

    static func preferredBundleID(forPetFrame frame: NSRect, selfBundleID: String?) -> String? {
        let screens = NSScreen.screens.map(\.frame)
        guard let monitor = AppPlacement.preferredSafeFrame(for: frame, candidates: screens) else { return nil }
        let skip = Set([selfBundleID].compactMap { $0 })
        return AppPlacement.preferredAppBundleID(
            monitor: monitor, candidates: candidates(excludingBundleIDs: skip), selfBundleID: selfBundleID)
    }

    static func candidates(excludingBundleIDs: Set<String>) -> [PlacementWindowCandidate] {
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        var result: [PlacementWindowCandidate] = []
        var z = 0
        for entry in info {
            guard let bundleID = bundleID(from: entry), !excludingBundleIDs.contains(bundleID) else { continue }
            guard let bounds = cgBounds(from: entry) else { continue }
            let layer = entry[kCGWindowLayer as String] as? Int ?? 0
            if layer != 0 { continue } // normal app windows only
            let fs = isFullscreen(bounds: bounds)
            result.append(PlacementWindowCandidate(bundleID: bundleID, bounds: bounds, zOrder: z, isFullscreen: fs))
            z += 1
        }
        return result
    }

    private static func bundleID(from entry: [String: Any]) -> String? {
        guard let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
              let app = NSRunningApplication(processIdentifier: pid) else { return nil }
        return app.bundleIdentifier
    }

    private static func cgBounds(from entry: [String: Any]) -> NSRect? {
        guard let dict = entry[kCGWindowBounds as String] as? [String: Any] else { return nil }
        var rect = CGRect.zero
        guard CGRectMakeWithDictionaryRepresentation(dict as CFDictionary, &rect) else { return nil }
        // CGWindowList bounds are Quartz global: origin at the top-left of the primary display.
        // AppKit screen/window frames use bottom-left of that same display.
        return appKitRect(fromQuartzBounds: rect, primaryHeight: primaryDisplayHeight)
    }

    /// Pure Quartz→AppKit flip: `yApp = primaryHeight - yQuartz - height`.
    static func appKitRect(fromQuartzBounds quartz: CGRect, primaryHeight: CGFloat) -> NSRect {
        NSRect(
            x: quartz.origin.x,
            y: primaryHeight - quartz.origin.y - quartz.size.height,
            width: quartz.size.width,
            height: quartz.size.height)
    }

    /// Height of the display whose AppKit frame origin is (0, 0) (Quartz primary).
    private static var primaryDisplayHeight: CGFloat {
        if let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) {
            return primary.frame.height
        }
        return NSScreen.main?.frame.height ?? NSScreen.screens.first?.frame.height ?? 0
    }

    private static func isFullscreen(bounds: NSRect) -> Bool {
        for screen in NSScreen.screens {
            let f = screen.frame
            if abs(bounds.minX - f.minX) <= fullscreenSlop,
               abs(bounds.maxX - f.maxX) <= fullscreenSlop,
               abs(bounds.minY - f.minY) <= fullscreenSlop,
               abs(bounds.maxY - f.maxY) <= fullscreenSlop {
                return true
            }
        }
        return false
    }
}
