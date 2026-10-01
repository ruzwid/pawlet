import Foundation

struct AppSettings: Codable, Equatable {
    var animateIdle = false
    var followCursor = false
    var wander = false
    var loopActivities = false
    var animateInteractions = true
    var greetOnHover = true
    var animationInterval = MotionConstants.DEFAULT_INTERVAL_SECONDS
    var paused = false
    var alwaysOnTop = true
    var clickThrough = false
    var allSpaces = true
    var showDockIcon = true
    var size = 1.0
    var speed = 1.0
    var opacity = 1.0
    var appearance = "system"

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: AppSettingsKey.self)
        animateIdle = try values.decodeIfPresent(Bool.self, forKey: .animateIdle) ?? animateIdle
        followCursor = try values.decodeIfPresent(Bool.self, forKey: .followCursor) ?? followCursor
        wander = try values.decodeIfPresent(Bool.self, forKey: .wander) ?? wander
        loopActivities = try values.decodeIfPresent(Bool.self, forKey: .loopActivities) ?? loopActivities
        animateInteractions = try values.decodeIfPresent(Bool.self, forKey: .animateInteractions) ?? animateInteractions
        greetOnHover = try values.decodeIfPresent(Bool.self, forKey: .greetOnHover) ?? greetOnHover
        animationInterval = try values.decodeIfPresent(Double.self, forKey: .animationInterval) ?? animationInterval
        paused = try values.decodeIfPresent(Bool.self, forKey: .paused) ?? paused
        alwaysOnTop = try values.decodeIfPresent(Bool.self, forKey: .alwaysOnTop) ?? alwaysOnTop
        clickThrough = try values.decodeIfPresent(Bool.self, forKey: .clickThrough) ?? clickThrough
        allSpaces = try values.decodeIfPresent(Bool.self, forKey: .allSpaces) ?? allSpaces
        showDockIcon = try values.decodeIfPresent(Bool.self, forKey: .showDockIcon) ?? showDockIcon
        size = try values.decodeIfPresent(Double.self, forKey: .size) ?? size
        speed = try values.decodeIfPresent(Double.self, forKey: .speed) ?? speed
        opacity = try values.decodeIfPresent(Double.self, forKey: .opacity) ?? opacity
        appearance = try values.decodeIfPresent(String.self, forKey: .appearance) ?? appearance
        animationInterval = min(MotionConstants.MAX_INTERVAL_SECONDS, max(0, animationInterval))
        size = min(1.75, max(0.65, size)); speed = min(1.5, max(0.5, speed)); opacity = min(1, max(0.3, opacity))
        if !["system", "light", "dark"].contains(appearance) { appearance = "system" }
    }
}

enum AppSettingsKey: String, CodingKey {
    case animateIdle, followCursor, wander, loopActivities, animateInteractions, greetOnHover, animationInterval
    case paused, alwaysOnTop, clickThrough, allSpaces, showDockIcon, size, speed, opacity, appearance
}
