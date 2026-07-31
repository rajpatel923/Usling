import Foundation
import Observation

/// Manages invite creation and pair acceptance.
/// Persists pairId in Keychain once paired.
@Observable @MainActor
final class PairingManager {
    static let shared = PairingManager()

    private(set) var pairId: String?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var isPaired: Bool { pairId != nil }

    private let keychain = KeychainManager.shared
    private let auth = AuthManager.shared

    // Server base URL — update to match your backend host in production
    private let apiBase: URL = {
        let str = Bundle.main.infoDictionary?["API_BASE_URL"] as? String
                  ?? "http://localhost:3000"
        return URL(string: str)!
    }()

    private init() {
        pairId = keychain.pairId
    }

    // MARK: - Generate invite

    /// Returns a 6-character code the user shares with their partner.
    @discardableResult
    func generateInviteCode() async -> String? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let token = try await auth.ensureValidToken()
            let url = apiBase.appending(path: "/pair/invite")
            // No request body — omit Content-Type to avoid Fastify's empty-JSON-body error
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, resp) = try await URLSession.shared.data(for: req)
            try assertOK(resp, data: data)

            let body = try JSONDecoder().decode(InviteResponse.self, from: data)
            return body.code
        } catch {
            errorMessage = errorMessage(from: error)
            return nil
        }
    }

    // MARK: - Accept invite

    /// Accepts a partner's invite code and stores the resulting pairId.
    @discardableResult
    func acceptInvite(code: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let token = try await auth.ensureValidToken()
            let url = apiBase.appending(path: "/pair/accept")
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(["code": code])

            let (data, resp) = try await URLSession.shared.data(for: req)
            try assertOK(resp, data: data)

            let body = try JSONDecoder().decode(AcceptResponse.self, from: data)
            pairId = body.pairId
            keychain.pairId = body.pairId
            return true
        } catch {
            errorMessage = errorMessage(from: error)
            return false
        }
    }

    // MARK: - Private helpers

    private func assertOK(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            if let body = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError(body.error)
            }
            throw APIError("Server error \(http.statusCode)")
        }
    }

    private func errorMessage(from error: Error) -> String {
        (error as? APIError)?.message ?? error.localizedDescription
    }
}

// MARK: - Response types

private struct InviteResponse: Decodable { let code: String }
private struct AcceptResponse: Decodable { let pairId: String }
private struct ErrorResponse: Decodable { let error: String }
private struct APIError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
