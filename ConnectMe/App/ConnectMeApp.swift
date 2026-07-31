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
    private var setupWindow: NSWindow?
    private var presenceBridgeTask: Task<Void, Never>?

    // Shared singletons wired together here
    private let presenceEngine = PresenceEngine()
    private let auth = AuthManager.shared
    private let pairing = PairingManager.shared
    private let wsManager = WebSocketManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        wireWebSocketCallbacks()

        if auth.isAuthenticated && pairing.isPaired {
            startOverlay()
        } else {
            showSetupWindow()
        }

        // Watch auth + pairing state to advance UI automatically
        presenceBridgeTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                await MainActor.run { [weak self] in
                    self?.checkSetupProgress()
                }
            }
        }
    }

    // MARK: - Deep link handling (Supabase magic link callback)

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "connectme" {
            Task { await auth.handleDeepLink(url) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Private

    private func wireWebSocketCallbacks() {
        // Local presence → send to partner
        presenceEngine.onStateChange = { [weak self] state in
            self?.wsManager.sendPresenceUpdate(state: state.rawValue)
        }

        // Partner presence → update engine
        wsManager.onPresenceUpdated = { [weak self] _, stateRaw in
            guard let self,
                  let state = PresenceState(rawValue: stateRaw) else { return }
            self.presenceEngine.applyPartnerPresence(state)
        }

        // Partner position → update engine
        wsManager.onPositionUpdated = { [weak self] _, x, y in
            self?.presenceEngine.applyPartnerPosition(x: x, y: y)
        }
        wsManager.onMessageReceived = { messageId, content, sentAt in
            Task { @MainActor in
                MessageManager.shared.receive(IncomingMessage(id: messageId, content: content, sentAt: sentAt))
            }
        }
    }

    private func checkSetupProgress() {
        guard setupWindow != nil else { return }
        if auth.isAuthenticated && pairing.isPaired {
            setupWindow?.close()
            setupWindow = nil
            startOverlay()
        }
    }

    private func startOverlay() {
        NSApp.setActivationPolicy(.accessory)

        let coordinator = OverlayCoordinator(presenceEngine: presenceEngine)
        coordinator.show()
        overlayCoordinator = coordinator
        statusBarController = StatusBarController(coordinator: coordinator)

        presenceEngine.start()

        Task { await wsManager.connect() }
    }

    private func showSetupWindow() {
        NSApp.setActivationPolicy(.regular)

        let view = SetupFlow(onTestOverlay: { [weak self] in
            self?.setupWindow?.close()
            self?.startOverlay()
        })
        .environment(auth)
        .environment(pairing)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 320),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ConnectMe Setup"
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.makeKeyAndOrderFront(nil)
        setupWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Top-level SwiftUI view that switches between onboarding and pairing steps.
private struct SetupFlow: View {
    @Environment(AuthManager.self) private var auth
    @Environment(PairingManager.self) private var pairing
    var onTestOverlay: (() -> Void)? = nil

    var body: some View {
        if !auth.isAuthenticated {
            OnboardingView()
                .safeOverlay(label: onTestOverlay)
        } else if !pairing.isPaired {
            PairingView()
                .safeOverlay(label: onTestOverlay)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
                Text("All set! Starting overlay…")
                    .font(.headline)
            }
            .frame(width: 380, height: 260)
        }
    }
}

private extension View {
    @ViewBuilder
    func safeOverlay(label action: (() -> Void)?) -> some View {
        #if DEBUG
        self.overlay(alignment: .bottomTrailing) {
            if let action {
                Button("Test Overlay") { action() }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
            }
        }
        #else
        self
        #endif
    }
}
