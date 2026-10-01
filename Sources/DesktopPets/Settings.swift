import Foundation

struct AppSettings: Codable, Equatable {
    var animateIdle = false
    var followCursor = false
    var wander = false
    var loopActivities = false
    var animateInteractions = true
    var paused = false
    var alwaysOnTop = true
    var clickThrough = false
    var allSpaces = true
    var showDockIcon = true
    var size = 1.0
    var speed = 1.0
    var opacity = 1.0
    var appearance = "system"
}
