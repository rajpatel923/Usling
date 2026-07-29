import AppKit

/// Transparent floating NSPanel that hosts the companion dots overlay.
/// Non-activating, floats above all apps, joins all Spaces and full-screen environments.
/// Click-through is handled by ClickThroughView.hitTest, not ignoresMouseEvents.
final class CompanionPanel: NSPanel {

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configure()
    }

    private func configure() {
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        // ignoresMouseEvents stays false — ClickThroughView.hitTest handles pass-through
        acceptsMouseMovedEvents = true
        isMovable = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
