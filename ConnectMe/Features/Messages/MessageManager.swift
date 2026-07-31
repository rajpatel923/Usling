import Foundation
import Observation

struct IncomingMessage: Identifiable {
    let id: String
    let content: String
    let sentAt: Date
}

@Observable @MainActor
final class MessageManager {
    static let shared = MessageManager()

    var pendingMessages: [IncomingMessage] = []
    var unreadCount: Int { pendingMessages.count }

    private let keychain = KeychainManager.shared
    private let apiBase: URL = {
        let str = Bundle.main.infoDictionary?["API_BASE_URL"] as? String ?? "http://localhost:3000"
        return URL(string: str)!
    }()

    private init() {}

    func receive(_ message: IncomingMessage) {
        pendingMessages.append(message)
    }

    func sendMessage(_ content: String) async {
        guard let token = try? await AuthManager.shared.ensureValidToken() else { return }

        var req = URLRequest(url: apiBase.appending(path: "/messages"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["content": content])

        _ = try? await URLSession.shared.data(for: req)
    }

    // Called when the inbox is dismissed — ACKs all displayed messages and clears them.
    func ackAll(via wsManager: WebSocketManager) {
        let toAck = pendingMessages
        pendingMessages.removeAll()
        for msg in toAck {
            wsManager.sendMessageAck(messageId: msg.id)
        }
    }
}
