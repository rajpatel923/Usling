import Foundation
import Observation

/// Drives the local user's coarse presence state from system sensor events.
/// Enforces hysteresis to prevent rapid state flapping.
@Observable @MainActor
final class PresenceEngine {
    private(set) var localState: PresenceState = .active

    /// Configurable idle threshold (seconds). Default: 5 minutes.
    var idleThreshold: TimeInterval = 300

    private let sensors: SensorEventSource
    private var sensorTask: Task<Void, Never>?

    // Dwell timers — cancelled when a competing event arrives.
    private var dwellTask: Task<Void, Never>?

    convenience init() {
        self.init(sensors: SystemSensorMonitor())
    }

    init(sensors: SensorEventSource) {
        self.sensors = sensors
    }

    func start() {
        sensorTask = Task { [weak self] in
            guard let self else { return }
            for await event in sensors.events {
                await self.handle(event)
            }
        }
    }

    func stop() {
        sensorTask?.cancel()
        dwellTask?.cancel()
    }

    // MARK: - State transitions

    private func handle(_ event: SensorEvent) async {
        switch event {
        case .sleep, .screenLock:
            transition(to: .sleeping, dwell: 0)

        case .wake, .screenUnlock:
            // Require 15 seconds of stability before leaving sleeping.
            guard localState == .sleeping else { return }
            transitionAfterDwell(to: .active, seconds: 15)

        case .idle:
            guard localState == .active else { return }
            transition(to: .away, dwell: 0)

        case .inputDetected:
            guard localState == .away else { return }
            // Require 30 seconds of input before promoting back to active.
            transitionAfterDwell(to: .active, seconds: 30)
        }
    }

    private func transition(to newState: PresenceState, dwell: TimeInterval) {
        dwellTask?.cancel()
        localState = newState
    }

    private func transitionAfterDwell(to newState: PresenceState, seconds: TimeInterval) {
        dwellTask?.cancel()
        dwellTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(seconds))
                guard let self, !Task.isCancelled else { return }
                self.localState = newState
            } catch { /* cancelled */ }
        }
    }
}
