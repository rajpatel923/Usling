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
        let localPoint = convert(point, from: superview)
        let myDist      = hypot(localPoint.x - store.myPosition.x,      localPoint.y - store.myPosition.y)
        let partnerDist = hypot(localPoint.x - store.partnerPosition.x, localPoint.y - store.partnerPosition.y)
        guard myDist <= store.hitRadius || partnerDist <= store.hitRadius else { return nil }
        // SwiftUI returns nil for Color.clear regions; fall back to self so the tap event reaches SwiftUI
        return super.hitTest(point) ?? self
    }
}
