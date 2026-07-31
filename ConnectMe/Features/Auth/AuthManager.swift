import Foundation
import Observation

/// Manages Supabase authentication using direct REST calls (no SDK).
/// Uses the implicit flow for magic links (tokens arrive in the URL hash).
@Observable @MainActor
final class AuthManager {
    static let shared = AuthManager()

    private(set) var isAuthenticated = false
    private(set) var userId: String?
    private(set) var userEmail: String?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let keychain = KeychainManager.shared

    // Read from Info.plist — set SUPABASE_URL and SUPABASE_ANON_KEY in
    // Xcode target settings: select target → Info tab → add the two keys.
    private var supabaseURL: String {
        let url = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
        assert(!url.isEmpty, "SUPABASE_URL missing from Info.plist — see AuthManager.swift")
        return url
    }
    private var anonKey: String {
        let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
        assert(!key.isEmpty, "SUPABASE_ANON_KEY missing from Info.plist — see AuthManager.swift")
        return key
    }


    private init() {
        restoreSession()
    }

    // MARK: - Public API

    /// Sends a Supabase magic link to `email`. The user clicks it; the app receives
    /// the `connectme://auth/callback` deep link and you call `handleDeepLink(_:)`.
    func sendMagicLink(to email: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var req = supabaseRequest(path: "/auth/v1/otp", method: "POST")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "email": email,
            "create_user": true,
            "options": [
                "redirect_to": "connectme://auth/callback",
            ],
        ])

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                let msg = (try? JSONDecoder().decode(SupabaseError.self, from: data))?.message
                errorMessage = msg ?? "Could not send magic link (HTTP \(http.statusCode))"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Call this from your AppDelegate `application(_:open:)` when a
    /// `connectme://auth/callback` URL arrives.
    /// Called from AppDelegate when `connectme://auth/callback#access_token=...` arrives.
    func handleDeepLink(_ url: URL) async {
        guard let fragment = url.fragment else { return }
        handleImplicitFragment(fragment)
    }

    func signOut() {
        keychain.clearAuth()
        isAuthenticated = false
        userId = nil
        userEmail = nil
    }

    /// Returns a valid access token, refreshing it automatically if expired or about to expire.
    /// Throws `URLError(.userAuthenticationRequired)` if unauthenticated or refresh fails.
    func ensureValidToken() async throws -> String {
        guard let token = keychain.accessToken else {
            throw URLError(.userAuthenticationRequired)
        }
        if let expiry = jwtExpiry(token), expiry < Date().addingTimeInterval(60) {
            let ok = await refreshSession()
            if !ok { signOut(); throw URLError(.userAuthenticationRequired) }
        }
        guard let fresh = keychain.accessToken else {
            throw URLError(.userAuthenticationRequired)
        }
        return fresh
    }

    /// Refreshes the session using the stored refresh token. Returns true on success.
    @discardableResult
    func refreshSession() async -> Bool {
        guard let refreshToken = keychain.refreshToken else { return false }

        var req = supabaseRequest(path: "/auth/v1/token?grant_type=refresh_token", method: "POST")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let session = try? JSONDecoder().decode(SupabaseSession.self, from: data) else {
            return false
        }
        applySession(session)
        return true
    }

    // MARK: - REST helpers

    private func supabaseRequest(path: String, method: String) -> URLRequest {
        let base = supabaseURL
        guard !base.isEmpty, let url = URL(string: base + path) else {
            fatalError("Invalid SUPABASE_URL '\(base)' — check Info.plist")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return req
    }

    private func handleImplicitFragment(_ fragment: String) {
        var params: [String: String] = [:]
        for pair in fragment.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2 { params[String(kv[0])] = String(kv[1]) }
        }
        guard let access  = params["access_token"],
              let refresh = params["refresh_token"] else { return }
        let (uid, email) = jwtPayload(access)
        applySession(SupabaseSession(
            access_token:  access,
            refresh_token: refresh,
            expires_in:    Int(params["expires_in"] ?? "3600") ?? 3600,
            user:          SupabaseUser(id: uid ?? "", email: email)
        ))
    }

    private func applySession(_ session: SupabaseSession) {
        isAuthenticated   = true
        userId            = session.user.id
        userEmail         = session.user.email
        keychain.accessToken  = session.access_token
        keychain.refreshToken = session.refresh_token
        keychain.userId       = session.user.id
        keychain.userEmail    = session.user.email
    }

    private func restoreSession() {
        guard let id    = keychain.userId,
              let email = keychain.userEmail,
              keychain.accessToken != nil else { return }
        userId          = id
        userEmail       = email
        isAuthenticated = true
    }

    // MARK: - JWT payload decoder

    private func jwtExpiry(_ token: String) -> Date? {
        guard let json = jwtClaims(token),
              let exp = json["exp"] as? TimeInterval else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    private func jwtPayload(_ token: String) -> (String?, String?) {
        guard let json = jwtClaims(token) else { return (nil, nil) }
        return (json["sub"] as? String, json["email"] as? String)
    }

    private func jwtClaims(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var b64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }
}

// MARK: - Data base64url helper

private extension Data {
    var base64url: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Decodable response types

private struct SupabaseSession: Decodable {
    let access_token:  String
    let refresh_token: String
    let expires_in:    Int
    let user:          SupabaseUser
}

private struct SupabaseUser: Decodable {
    let id:    String
    let email: String?
}

private struct SupabaseError: Decodable {
    let message: String?
    let error_description: String?
}


