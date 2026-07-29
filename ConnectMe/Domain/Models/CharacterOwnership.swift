import SwiftUI

/// Which of the two paired users owns a character.
enum CharacterOwnership: Equatable {
    case mine
    case partner

    /// Primary tint for the dot — must not be the sole differentiator (see `shape`).
    var tintColor: Color {
        switch self {
        case .mine: .blue
        case .partner: Color(.systemPink)
        }
    }

    /// Secondary visual differentiator for color-blind accessibility.
    var accessibilityLabel: String {
        switch self {
        case .mine: "Your companion"
        case .partner: "Partner's companion"
        }
    }

    var isDraggable: Bool { self == .mine }
}
