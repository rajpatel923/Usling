import CoreGraphics

/// Shared state between SwiftUI (OverlayHostView) and AppKit (ClickThroughView).
/// ClickThroughView reads this to decide which screen areas accept mouse events.
final class DotPositionStore {
    /// My dot's current position in SwiftUI view-space (top-left origin, same as GeometryReader).
    var myPosition: CGPoint = .zero
    /// Partner dot's current position — updated as presence events arrive.
    var partnerPosition: CGPoint = .zero
    /// Generous hit radius for usability (dot is 48pt, hitRadius is 36pt).
    let hitRadius: CGFloat = 36
}
