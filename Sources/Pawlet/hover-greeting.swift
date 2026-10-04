import Foundation

struct HoverGreeting {
    private var wasHovering = false
    mutating func shouldGreet(isHovering: Bool, isEnabled: Bool, isBlocked: Bool) -> Bool {
        let didEnter = isHovering && !wasHovering
        wasHovering = isHovering
        return didEnter && isEnabled && !isBlocked
    }
}
