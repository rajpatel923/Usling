import SwiftUI

/// Full-screen transparent SwiftUI view hosted inside the CompanionPanel.
/// Owns both dot positions; only the owned dot is draggable.
struct OverlayHostView: View {
    @Environment(PresenceEngine.self) private var presenceEngine
    @Environment(WebSocketManager.self) private var wsManager

    /// Shared with ClickThroughView so AppKit knows where the interactive area is.
    let dotStore: DotPositionStore

    @State private var myPosition: CGPoint = .zero
    @State private var dragSessionId: String = UUID().uuidString
    @State private var showMessagePanel = false

    private var messageManager: MessageManager { MessageManager.shared }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.clear

                // Partner dot — tappable for messaging; badge shows unread count
                let partnerPos = denormalized(presenceEngine.partnerNormalizedPosition, in: geo.size)
                ZStack(alignment: .topTrailing) {
                    DotView(
                        ownership: .partner,
                        animationState: presenceEngine.partnerState.dotAnimationState
                    )
                    if messageManager.unreadCount > 0 {
                        Text("\(messageManager.unreadCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.red, in: Capsule())
                            .offset(x: 8, y: -8)
                    }
                }
                .position(partnerPos)
                .onTapGesture { showMessagePanel = true }
                .popover(isPresented: $showMessagePanel, arrowEdge: .bottom) {
                    if messageManager.unreadCount > 0 {
                        InboxView(messageManager: messageManager, wsManager: wsManager)
                    } else {
                        ComposeView(messageManager: messageManager, wsManager: wsManager)
                    }
                }
                .onChange(of: partnerPos) {
                    dotStore.partnerPosition = partnerPos
                }

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
                            let norm = normalized(pos, in: geo.size)
                            wsManager.sendPositionUpdate(
                                characterId: KeychainManager.shared.userId ?? "me",
                                dragSessionId: dragSessionId,
                                x: norm.x, y: norm.y
                            )
                        }
                        .onEnded { value in
                            let pos = clamped(value.location, in: geo.size)
                            myPosition = pos
                            dotStore.myPosition = pos
                            dragSessionId = UUID().uuidString
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
                dotStore.myPosition = myPosition
                presenceEngine.partnerNormalizedPosition = CGPoint(x: 0.6, y: 0.5)
                // Set immediately so hitTest has the correct position before onChange fires
                dotStore.partnerPosition = denormalized(CGPoint(x: 0.6, y: 0.5), in: geo.size)
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

    private func normalized(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x / size.width, y: point.y / size.height)
    }

    private func denormalized(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }
}
