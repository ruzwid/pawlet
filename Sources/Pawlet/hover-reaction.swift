import Foundation

enum HoverReaction: String, CaseIterable, Codable {
    case wave, hop, waiting, working, reviewing, oops

    var state: PetState {
        switch self {
        case .wave: return .waving
        case .hop: return .jumping
        case .waiting: return .waiting
        case .working: return .working
        case .reviewing: return .review
        case .oops: return .failed
        }
    }
    var title: String { self == .hop ? "Hop toward you" : state.title }
    var detail: String {
        self == .hop ? "Plays the Jump animation. Paris's forward hop uses this row." : "Plays one full \(state.title.lowercased()) animation, then returns to idle."
    }
}

extension PetState {
    var symbol: String {
        switch self {
        case .idle: return "leaf"
        case .runningRight: return "arrow.right"
        case .runningLeft: return "arrow.left"
        case .waving: return "hand.wave"
        case .jumping: return "arrow.up"
        case .failed: return "cloud.rain"
        case .waiting: return "hourglass"
        case .working: return "sparkles"
        case .review: return "magnifyingglass"
        }
    }
    var detail: String {
        switch self {
        case .idle: return "Small movements, a little personality."
        case .runningRight: return "A right-facing gait, played in place."
        case .runningLeft: return "A left-facing gait, played in place."
        case .waving: return "A friendly hello."
        case .jumping: return "A playful hop. Some minis bounce toward you."
        case .failed: return "A little reaction when things go wrong."
        case .waiting: return "Patiently keeping you company."
        case .working: return "The active-work animation; artwork varies by mini."
        case .review: return "Thinking it over."
        }
    }
}
