import AppKit
import CoreGraphics

/// Events emitted by the system sensor monitor.
enum SensorEvent {
    case sleep
    case wake
    case screenLock
    case screenUnlock
    case idle(duration: TimeInterval)
    case inputDetected
}

/// Produces a stream of system sensor events using only zero-permission APIs.
protocol SensorEventSource {
    var events: AsyncStream<SensorEvent> { get }
}

/// Concrete implementation using NSWorkspace notifications, distributed notifications,
/// and CGEventSource idle time — no Screen Recording or Accessibility required.
final class SystemSensorMonitor: SensorEventSource {
    private let continuation: AsyncStream<SensorEvent>.Continuation
    let events: AsyncStream<SensorEvent>

    /// How long without input before emitting `.idle`. Configurable for testing.
    var idleThreshold: TimeInterval = 300  // 5 minutes

    private var idleTimer: Timer?
    private var wasIdle = false

    init() {
        var cont: AsyncStream<SensorEvent>.Continuation!
        events = AsyncStream { cont = $0 }
        continuation = cont
        registerNotifications()
        startIdlePolling()
    }

    deinit {
        idleTimer?.invalidate()
        continuation.finish()
    }

    // MARK: - NSWorkspace notifications

    private func registerNotifications() {
        let workspace = NSWorkspace.shared
        let nc = workspace.notificationCenter
        let dnc = DistributedNotificationCenter.default()

        let workspaceEvents: [(NSNotification.Name, SensorEvent)] = [
            (NSWorkspace.willSleepNotification, .sleep),
            (NSWorkspace.screensDidSleepNotification, .sleep),
            (NSWorkspace.didWakeNotification, .wake),
            (NSWorkspace.screensDidWakeNotification, .wake),
            (NSWorkspace.sessionDidResignActiveNotification, .sleep),
            (NSWorkspace.sessionDidBecomeActiveNotification, .wake),
        ]

        for (name, event) in workspaceEvents {
            nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.emit(event)
            }
        }

        // Screen lock/unlock — no permission needed
        dnc.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"),
                        object: nil, queue: .main) { [weak self] _ in self?.emit(.screenLock) }
        dnc.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"),
                        object: nil, queue: .main) { [weak self] _ in self?.emit(.screenUnlock) }
    }

    // MARK: - Idle detection (no permissions)

    private func startIdlePolling() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkIdle()
        }
    }

    private func checkIdle() {
        let idle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState, eventType: .mouseMoved
        )
        if idle >= idleThreshold && !wasIdle {
            wasIdle = true
            emit(.idle(duration: idle))
        } else if idle < 30 && wasIdle {
            wasIdle = false
            emit(.inputDetected)
        }
    }

    private func emit(_ event: SensorEvent) {
        continuation.yield(event)
    }
}
