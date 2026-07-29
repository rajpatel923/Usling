import SwiftUI

/// Full-screen transparent SwiftUI view hosted inside the CompanionPanel.
/// Owns both dot positions; only the owned dot is draggable.
struct OverlayHostView: View {
    @Environment(PresenceEngine.self) private var presenceEngine

    /// Shared with ClickThroughView so AppKit knows where the interactive area is.
    let dotStore: DotPositionStore

    @State private var myPosition: CGPoint = .zero
    @State private var partnerPosition: CGPoint = CGPoint(x: 120, y: 120)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.clear

                // Partner dot — not draggable
                DotView(
                    ownership: .partner,
                    animationState: presenceEngine.localState.dotAnimationState
                )
                .position(partnerPosition)

                // My dot — draggable; updates dotStore so ClickThroughView stays in sync
                DotView(
                    ownership: .mine,
                    animationState: presenceEngine.localState.dotAnimationState
                )
                .position(myPosition)
                .gesture(
                    DragGesture(minimumDistance: 2, coordinateSpace: .local)
                        .onChanged { value in
                            let pos = clamped(value.location, in: geo.size)
                            myPosition = pos
                            dotStore.myPosition = pos
                        }
                        .onEnded { value in
                            let pos = clamped(value.location, in: geo.size)
                            myPosition = pos
                            dotStore.myPosition = pos
                        }
                )
                .onHover { inside in
                    NSCursor.openHand.set()
                    if !inside { NSCursor.arrow.set() }
                }
            }
            .onAppear {
                let cx = geo.size.width / 2
                let cy = geo.size.height / 2
                myPosition = CGPoint(x: cx - 70, y: cy)
                partnerPosition = CGPoint(x: cx + 70, y: cy)
                dotStore.myPosition = myPosition
            }
        }
    }

    private func clamped(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let margin: CGFloat = 32
        return CGPoint(
            x: max(margin, min(size.width - margin, point.x)),
            y: max(margin, min(size.height - margin, point.y))
        )
    }
}
