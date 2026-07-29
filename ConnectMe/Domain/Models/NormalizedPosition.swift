import CoreGraphics

/// Screen-independent position in the range [0, 1] x [0, 1].
struct NormalizedPosition: Equatable, Codable {
    /// 0 = left edge, 1 = right edge of the visible frame.
    var x: Double
    /// 0 = top edge, 1 = bottom edge of the visible frame.
    var y: Double

    static let center = NormalizedPosition(x: 0.5, y: 0.5)

    /// Clamp both axes to valid range.
    func clamped() -> NormalizedPosition {
        NormalizedPosition(x: max(0, min(1, x)), y: max(0, min(1, y)))
    }
}
