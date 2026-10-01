import Foundation

enum PetState: String, CaseIterable {
    case idle, runningRight = "running-right", runningLeft = "running-left"
    case waving, jumping, failed, waiting, working = "running", review

    var row: Int { Self.allCases.firstIndex(of: self)! }
    var count: Int { [6, 8, 8, 4, 5, 8, 6, 6, 6][row] }
    var secondsPerFrame: Double { [0.28, 0.12, 0.12, 0.14, 0.14, 0.14, 0.15, 0.14, 0.15][row] }
    var title: String { ["Idle", "Run right", "Run left", "Wave", "Jump", "Oops", "Waiting", "Working", "Reviewing"][row] }
    var transient: Bool { self == .waving || self == .jumping }
}

struct SpriteFrame: Equatable {
    let row: Int
    let column: Int
}

enum Gaze {
    /// Screen coordinates use positive y upward. Zero is up, then clockwise.
    static func index(dx: Double, dy: Double) -> Int {
        let turns = atan2(dx, dy) / (2 * Double.pi)
        return (Int((turns * 16).rounded()) % 16 + 16) % 16
    }

    static func frame(dx: Double, dy: Double) -> SpriteFrame {
        let i = index(dx: dx, dy: dy)
        return SpriteFrame(row: 9 + i / 8, column: i % 8)
    }
}

final class AnimationEngine {
    var baseState: PetState = .idle
    private(set) var action: PetState?
    private var actionUntil: Double = 0
    private var key = ""
    private var started: Double = 0

    func perform(_ state: PetState, now: Double, seconds: Double? = nil, speed: Double = 1) {
        key = "" // Repeated greetings restart from the first frame.
        if let seconds = seconds, seconds > 0 {
            action = state
            actionUntil = now + min(seconds, 3600)
        } else if state.transient {
            action = state
            actionUntil = now + Double(state.count) * state.secondsPerFrame / min(1.5, max(0.5, speed))
        } else {
            baseState = state
            action = nil
        }
    }

    func reset() { baseState = .idle; action = nil; key = "" }

    func frame(now: Double, drag: PetState? = nil, gaze: SpriteFrame? = nil,
               paused: Bool = false, reducedMotion: Bool = false,
               animateIdle: Bool = true, loopActivities: Bool = true, speed: Double = 1) -> SpriteFrame {
        if action != nil && now >= actionUntil { action = nil }
        let state = drag ?? action ?? baseState
        if state == .idle, action == nil, drag == nil, let gaze = gaze, !paused, !reducedMotion {
            key = "look"
            return gaze
        }
        if key != state.rawValue { key = state.rawValue; started = now }
        let elapsed = Int(max(0, now - started) * min(1.5, max(0.5, speed)) / state.secondsPerFrame)
        let still = paused || reducedMotion || (state == .idle && !animateIdle)
        let shouldLoop = drag != nil || state == .idle || loopActivities || state.transient
        let column = still ? 0 : (shouldLoop ? elapsed % state.count : min(elapsed, state.count - 1))
        return SpriteFrame(row: state.row, column: column)
    }
}

struct StateCommand {
    let pet: String
    let state: PetState
    let seconds: Double?

    static func parse(_ url: URL) -> StateCommand? {
        guard url.scheme?.lowercased() == "desktoppets", url.host?.lowercased() == "state",
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let items = parts.queryItems ?? []
        let pet = items.first(where: { $0.name == "pet" })?.value ?? "both"
        guard !pet.isEmpty, pet.count <= 64,
              let raw = items.first(where: { $0.name == "state" })?.value,
              let state = PetState(rawValue: raw) else { return nil }
        var seconds: Double?
        if let value = items.first(where: { $0.name == "seconds" })?.value {
            guard let number = Double(value), number.isFinite, number >= 0, number <= 3600 else { return nil }
            seconds = number > 0 ? number : nil
        }
        return StateCommand(pet: pet.lowercased(), state: state, seconds: seconds)
    }
}
