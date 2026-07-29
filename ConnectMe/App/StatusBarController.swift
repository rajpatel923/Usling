import AppKit

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private weak var coordinator: OverlayCoordinator?

    init(coordinator: OverlayCoordinator) {
        self.coordinator = coordinator
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configure()
    }

    private func configure() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Pair Companion")
        button.image?.isTemplate = true

        let menu = NSMenu()
        menu.addItem(showHideItem())
        menu.addItem(.separator())
        menu.addItem(settingsItem())
        menu.addItem(.separator())
        menu.addItem(quitItem())
        statusItem.menu = menu
    }

    private func showHideItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Show Companion", action: #selector(toggleOverlay), keyEquivalent: "")
        item.target = self
        return item
    }

    private func settingsItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func quitItem() -> NSMenuItem {
        NSMenuItem(title: "Quit Pair Companion", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @objc private func toggleOverlay() {
        guard let coordinator else { return }
        if coordinator.isVisible {
            coordinator.hide()
            (statusItem.menu?.item(at: 0))?.title = "Show Companion"
        } else {
            coordinator.show()
            (statusItem.menu?.item(at: 0))?.title = "Hide Companion"
        }
    }
}
