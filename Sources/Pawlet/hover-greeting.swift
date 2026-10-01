import Foundation

struct HoverGreeting {
    private var wasHovering = false
    private var nextGreetingTime = -Double.infinity

    mutating func shouldGreet(isHovering: Bool, now: Double, isEnabled: Bool, isBlocked: Bool, cooldown: Double) -> Bool {
        let didEnter = isHovering && !wasHovering
        wasHovering = isHovering
        guard didEnter, isEnabled, !isBlocked, now >= nextGreetingTime else { return false }
        nextGreetingTime = now + max(MotionConstants.HOVER_COOLDOWN_SECONDS, cooldown)
        return true
    }
}
