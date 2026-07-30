import AppKit
import SwiftUI

/// Manages the CompanionPanel lifecycle: creation, show, hide, screen tracking.
@MainActor
final class OverlayCoordinator {
    private(set) var isVisible = false
    private var panel: CompanionPanel?
    private let presenceEngine: PresenceEngine
    private let dotStore = DotPositionStore()

    init(presenceEngine: PresenceEngine) {
        self.presenceEngine = presenceEngine
        observeScreenChanges()
    }

    func show() {
        if panel == nil { buildPanel() }
        panel?.orderFrontRegardless()
        isVisible = true
    }

    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    // MARK: - Panel construction

    private func buildPanel() {
        guard let screen = NSScreen.main else { return }
        let p = CompanionPanel(screen: screen)

        let hostView = OverlayHostingView(
            rootView: AnyView(
                OverlayHostView(dotStore: dotStore)
                    .environment(presenceEngine)
                    .environment(WebSocketManager.shared)
                    .ignoresSafeArea()
            )
        )
        hostView.dotStore = dotStore
        hostView.frame = NSRect(origin: .zero, size: screen.frame.size)
        p.contentView = hostView
        p.setFrame(screen.frame, display: false)
        panel = p
    }

    // MARK: - Display change recovery

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let coordinator = self else { return }
            Task { @MainActor in
                coordinator.handleScreenChange()
            }
        }
    }

    private func handleScreenChange() {
        guard let screen = NSScreen.main, let panel else { return }
        panel.setFrame(screen.frame, display: true)
        panel.contentView?.frame = NSRect(origin: .zero, size: screen.frame.size)
    }
}
