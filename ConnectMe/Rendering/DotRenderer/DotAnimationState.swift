import Foundation

/// Animation state that drives the dot's visual appearance.
enum DotAnimationState: Equatable, CaseIterable {
    case idle        // gentle pulse — resting state
    case active      // bright, steady
    case away        // dimmed, slow float
    case sleeping    // small, still, very dim
    case unavailable // near-transparent, no animation
}

extension PresenceState {
    var dotAnimationState: DotAnimationState {
        switch self {
        case .active: .active
        case .away: .away
        case .sleeping: .sleeping
        case .unavailable: .unavailable
        }
    }
}
