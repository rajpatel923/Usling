import Foundation

/// Coarse presence state visible to the partner. Four states only — no history, no exact timestamps.
enum PresenceState: String, Codable, Equatable, CaseIterable {
    /// Mac awake, recent local input, heartbeat healthy.
    case active
    /// Mac awake but input idle past threshold.
    case away
    /// System or display sleep, or screen locked.
    case sleeping
    /// Missed heartbeats, app quit, network loss, muted, or disconnected.
    /// Partner cannot distinguish the cause — all silent conditions map here.
    case unavailable
}
