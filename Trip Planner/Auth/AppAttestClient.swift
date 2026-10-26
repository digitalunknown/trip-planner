import Foundation
import DeviceCheck
import CryptoKit

/// Handles App Attest key lifecycle and retrieval of short-lived app tokens
/// from the proxy's `POST /api/auth/app-attest` endpoint.
actor AppAttestClient {
    static let shared = AppAttestClient()
    
    private let keychainKeyId = "appAttest.keyId"
    private let keychainToken = "appAuth.token"
    private let keychainTokenExpiry = "appAuth.token.expiry"
    
    private var cachedToken: String?
    private var cachedExpiry: Date?
    private var cachedKeyId: String?
    
    init() {
        cachedKeyId = KeychainHelper.getString(forKey: keychainKeyId)
        cachedToken = KeychainHelper.getString(forKey: keychainToken)
        if let ts = KeychainHelper.getString(forKey: keychainTokenExpiry),
           let seconds = TimeInterval(ts) {
            cachedExpiry = Date(timeIntervalSince1970: seconds)
        }
    }
    
    /// Returns a valid token, refreshing it if missing or expired.
    func validToken(appleTransactionJws: String?) async throws -> String {
        if let token = cachedToken, let expiry = cachedExpiry, expiry > Date().addingTimeInterval(30) {
            return token
        }
        let keyId = try await ensureKeyId()
        let attestation = try await attestIfSupported(keyId: keyId)
        let token = try await issueToken(
            keyId: keyId,
            attestationObject: attestation?.attestationObject,
            clientDataHash: attestation?.clientDataHash,
            challenge: attestation?.challenge,
            appleTransactionJws: appleTransactionJws
        )
        return token
    }
    
    /// Clears the cached token so the next call fetches a new one.
    func invalidateToken() {
        cachedToken = nil
        cachedExpiry = nil
        KeychainHelper.delete(forKey: keychainToken)
        KeychainHelper.delete(forKey: keychainTokenExpiry)
    }
    
    // MARK: - Private
    
    private func ensureKeyId() async throws -> String {
        if let id = cachedKeyId, !id.isEmpty {
            return id
        }
        let id: String
        if DCAppAttestService.shared.isSupported {
            id = try await withCheckedThrowingContinuation { cont in
                DCAppAttestService.shared.generateKey { keyId, error in
                    if let error = error {
                        cont.resume(throwing: error)
                        return
                    }
                    guard let keyId, !keyId.isEmpty else {
                        cont.resume(throwing: NSError(domain: "AppAttest", code: -1, userInfo: [NSLocalizedDescriptionKey: "No keyId returned"]))
                        return
                    }
                    cont.resume(returning: keyId)
                }
            }
        } else {
            // Simulator or unsupported device: generate a stable random ID once.
            id = UUID().uuidString
        }
        try KeychainHelper.setString(id, forKey: keychainKeyId)
        cachedKeyId = id
        return id
    }
    
    private struct AttestationBundle {
        let attestationObject: Data
        let clientDataHash: Data
        let challenge: Data
    }
    
    private func attestIfSupported(keyId: String) async throws -> AttestationBundle? {
        guard DCAppAttestService.shared.isSupported else { return nil }
        let challenge = randomChallenge(length: 32)
        let hash = Data(SHA256.hash(data: challenge))
        let attObj: Data = try await withCheckedThrowingContinuation { cont in
            DCAppAttestService.shared.attestKey(keyId, clientDataHash: hash) { attestationObject, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                guard let attestationObject else {
                    cont.resume(throwing: NSError(domain: "AppAttest", code: -2, userInfo: [NSLocalizedDescriptionKey: "No attestationObject"]))
                    return
                }
                cont.resume(returning: attestationObject)
            }
        }
        return AttestationBundle(attestationObject: attObj, clientDataHash: hash, challenge: challenge)
    }
    
    private func issueToken(
        keyId: String,
        attestationObject: Data?,
        clientDataHash: Data?,
        challenge: Data?,
        appleTransactionJws: String?
    ) async throws -> String {
        let url = try Self.appAuthURL()
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any?] = [
            "keyId": keyId,
            "attestationObject": attestationObject.map { Self.base64url($0) },
            "clientDataHash": clientDataHash?.base64EncodedString(),
            "challenge": challenge?.base64EncodedString(),
            "appleTransactionJws": (appleTransactionJws ?? "").isEmpty ? nil : appleTransactionJws
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 }, options: [.sortedKeys])
        
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "AppAttest", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        guard (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "AppAttest", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Auth failed (\(http.statusCode)) \(detail)"])
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let token = json?["token"] as? String else {
            throw NSError(domain: "AppAttest", code: -4, userInfo: [NSLocalizedDescriptionKey: "Missing token"])
        }
        let ttl = (json?["expiresInSeconds"] as? Double) ?? 15 * 60
        let expiry = Date().addingTimeInterval(max(30, ttl - 30))
        cachedToken = token
        cachedExpiry = expiry
        try KeychainHelper.setString(token, forKey: keychainToken)
        try KeychainHelper.setString(String(expiry.timeIntervalSince1970), forKey: keychainTokenExpiry)
        return token
    }
    
    private static func appAuthURL() throws -> URL {
        // Build from the AI client's default endpoint host, replacing path.
        let ai = TripStacksAIClient.defaultEndpoint
        var comps = URLComponents(url: ai, resolvingAgainstBaseURL: false)
        comps?.path = "/api/auth/app-attest"
        guard let url = comps?.url else {
            throw NSError(domain: "AppAttest", code: -5, userInfo: [NSLocalizedDescriptionKey: "Invalid auth URL"])
        }
        return url
    }
    
    private func randomChallenge(length: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: max(16, length))
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }
    
    private static func base64url(_ data: Data) -> String {
        let s = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return s
    }
}

