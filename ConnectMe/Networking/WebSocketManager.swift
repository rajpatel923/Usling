import Foundation
import Observation

// MARK: - Incoming event types

struct IncomingEnvelope: Decodable {
    let type: String
    let actorId: String?
    let pairId: String?
}

struct PresenceUpdatedEvent: Decodable {
    struct Payload: Decodable { let state: String }
    let actorId: String
    let payload: Payload
}

struct PositionUpdatedEvent: Decodable {
    struct Payload: Decodable {
        let characterId: String
        let x: Double
        let y: Double
    }
    let actorId: String
    let payload: Payload
}

struct SessionReadyEvent: Decodable {
    struct Payload: Decodable { let pairId: String }
    let payload: Payload
}

// MARK: - Outgoing event builder

private struct OutgoingEvent<P: Encodable>: Encodable {
    let version = 1
    let type: String
    let eventId = UUID().uuidString
    let pairId: String
    let actorId: String
    let deviceId: String
    let sentAt: String
    let payload: P
}

// MARK: - WebSocketManager

/// Manages a persistent WebSocket connection to the relay server.
/// Handles auth, exponential-backoff reconnect, protocol-level heartbeat,
/// and an offline outbound queue.
@Observable @MainActor
final class WebSocketManager {
    static let shared = WebSocketManager()

    enum ConnectionState { case disconnected, connecting, connected }
    private(set) var connectionState: ConnectionState = .disconnected

    // Callbacks — set by AppDelegate after both managers are created
    var onPresenceUpdated: ((String, String) -> Void)?   // actorId, state
    var onPositionUpdated: ((String, Double, Double) -> Void)?  // actorId, x, y

    private let keychain = KeychainManager.shared
    private var wsTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempts = 0

    // Offline queue: events buffered while disconnected
    private var outboundQueue: [String] = []
    private let maxQueueDepth = 50

    private let apiBase: URL = {
        let str = Bundle.main.infoDictionary?["API_BASE_URL"] as? String
                  ?? "http://localhost:3001"
        return URL(string: str)!
    }()

    private init() {}

    // MARK: - Lifecycle

    func connect() async {
        guard connectionState == .disconnected else { return }
        connectionState = .connecting

        guard let token = keychain.accessToken,
              let userId = keychain.userId,
              let pairId = keychain.pairId else {
            connectionState = .disconnected
            return
        }

        // Resolve WebSocket URL from the /session endpoint
        guard let wsURL = await resolveWSURL(token: token) else {
            scheduleReconnect()
            return
        }

        var req = URLRequest(url: wsURL)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.webSocketTask(with: req)
        wsTask = task
        task.resume()

        connectionState = .connected
        reconnectAttempts = 0

        startReceiving(task: task, userId: userId, pairId: pairId)
        flushQueue()
    }

    func disconnect() {
        receiveTask?.cancel()
        reconnectTask?.cancel()
        wsTask?.cancel(with: .goingAway, reason: nil)
        wsTask = nil
        connectionState = .disconnected
    }

    // MARK: - Send helpers

    func sendPresenceUpdate(state: String) {
        guard let pairId = keychain.pairId, let userId = keychain.userId else { return }
        struct Payload: Encodable { let state: String }
        enqueue(OutgoingEvent(type: "presence.updated", pairId: pairId, actorId: userId,
                              deviceId: keychain.deviceId, sentAt: iso8601Now(),
                              payload: Payload(state: state)))
    }

    func sendPositionUpdate(characterId: String, dragSessionId: String, x: Double, y: Double) {
        guard let pairId = keychain.pairId, let userId = keychain.userId else { return }
        struct Payload: Encodable {
            let dragSessionId: String; let characterId: String
            let x: Double; let y: Double
        }
        enqueue(OutgoingEvent(type: "position.updated", pairId: pairId, actorId: userId,
                              deviceId: keychain.deviceId, sentAt: iso8601Now(),
                              payload: Payload(dragSessionId: dragSessionId,
                                               characterId: characterId, x: x, y: y)))
    }

    // MARK: - Private: receive loop

    private func startReceiving(task: URLSessionWebSocketTask, userId: String, pairId: String) {
        receiveTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    let message = try await task.receive()
                    await self.handle(message: message, myUserId: userId)
                } catch {
                    await MainActor.run { [weak self] in
                        self?.connectionState = .disconnected
                        self?.scheduleReconnect()
                    }
                    return
                }
            }
        }
    }

    private func handle(message: URLSessionWebSocketTask.Message, myUserId: String) {
        let data: Data
        switch message {
        case .string(let s): data = Data(s.utf8)
        case .data(let d):   data = d
        @unknown default: return
        }

        let decoder = JSONDecoder()
        guard let base = try? decoder.decode(IncomingEnvelope.self, from: data) else { return }

        // Ignore echoed own events
        if base.actorId == myUserId { return }

        switch base.type {
        case "presence.updated":
            if let event = try? decoder.decode(PresenceUpdatedEvent.self, from: data) {
                onPresenceUpdated?(event.actorId, event.payload.state)
            }
        case "position.updated":
            if let event = try? decoder.decode(PositionUpdatedEvent.self, from: data) {
                onPositionUpdated?(event.actorId, event.payload.x, event.payload.y)
            }
        default:
            break
        }
    }

    // MARK: - Private: queueing

    private func enqueue<P: Encodable>(_ event: OutgoingEvent<P>) {
        guard let json = try? String(data: JSONEncoder().encode(event), encoding: .utf8) else { return }
        if connectionState == .connected {
            rawSend(json)
        } else {
            if outboundQueue.count >= maxQueueDepth { outboundQueue.removeFirst() }
            outboundQueue.append(json)
        }
    }

    private func flushQueue() {
        let pending = outboundQueue
        outboundQueue.removeAll()
        for json in pending { rawSend(json) }
    }

    private func rawSend(_ json: String) {
        wsTask?.send(.string(json)) { _ in /* fire-and-forget */ }
    }

    // MARK: - Private: reconnect

    private func scheduleReconnect() {
        guard reconnectTask == nil || reconnectTask!.isCancelled else { return }
        let base = min(30.0, pow(2.0, Double(reconnectAttempts)))
        let jitter = Double.random(in: 0.8...1.2)
        let delay = base * jitter
        reconnectAttempts += 1

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await self?.connect()
        }
    }

    // MARK: - Private: session resolution

    private func resolveWSURL(token: String) async -> URL? {
        let url = apiBase.appending(path: "/session")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        struct SessionResponse: Decodable { let wsUrl: String }
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let body = try? JSONDecoder().decode(SessionResponse.self, from: data),
              let wsURL = URL(string: body.wsUrl) else { return nil }
        return wsURL
    }

    // MARK: - Utilities

    private func iso8601Now() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
