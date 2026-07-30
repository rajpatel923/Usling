import AppKit
import SwiftUI

/// NSHostingView subclass that handles its own click-through logic.
///
/// NSHostingView.isFlipped is true, so hitTest coordinates match SwiftUI's
/// top-left origin directly — no coordinate conversion needed.
final class OverlayHostingView: NSHostingView<AnyView> {
    var dotStore: DotPositionStore?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let store = dotStore else { return nil }
        // point arrives in the superview's coordinate system (AppKit bottom-left origin).
        // NSHostingView.isFlipped == true, so converting to our own space gives top-left
        // origin coordinates that match store.myPosition (set from SwiftUI's GeometryReader).
        let localPoint = convert(point, from: superview)
        let d = hypot(localPoint.x - store.myPosition.x, localPoint.y - store.myPosition.y)
        guard d <= store.hitRadius else { return nil }
        return super.hitTest(point)
    }
}
