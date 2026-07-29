import SwiftUI
import AppKit

@main
struct ConnectMeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayCoordinator: OverlayCoordinator?
    private var statusBarController: StatusBarController?
    private let presenceEngine = PresenceEngine()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let coordinator = OverlayCoordinator(presenceEngine: presenceEngine)
        coordinator.show()
        overlayCoordinator = coordinator

        statusBarController = StatusBarController(coordinator: coordinator)

        presenceEngine.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
