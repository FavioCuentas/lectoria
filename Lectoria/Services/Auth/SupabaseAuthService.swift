import Foundation
import Observation
import os

// MARK: - SupabaseAuthService

/// Implementación aislada de red del servicio de autenticación con Supabase GoTrue API.
///
/// Realiza peticiones directas HTTPS mediante `URLSession` para evitar dependencias pesadas.
/// Almacena tokens de sesión y perfiles de usuario en el Keychain de forma segura.
@Observable
public final class SupabaseAuthService: AuthService, @unchecked Sendable {
    public private(set) var currentUser: UserProfile? = nil
    public private(set) var sessionToken: String? = nil

    private let supabaseURL: String
    private let anonKey: String
    private let logger = Logger(subsystem: "com.orvexa.Lectoria", category: "Auth")

    public init(supabaseURL: String, anonKey: String) {
        self.supabaseURL = supabaseURL
        self.anonKey = anonKey

        // Restaurar sesión persistida en Keychain si existe
        if let tokenData = KeychainHelper.load(key: "sessionToken"),
           let token = String(data: tokenData, encoding: .utf8) {
            self.sessionToken = token

            if let profileData = KeychainHelper.load(key: "userProfile"),
               let profile = try? JSONDecoder().decode(UserProfile.self, from: profileData) {
                self.currentUser = profile
            }
        }
    }

    /// Configura los encabezados estándar HTTP para comunicarse con Supabase API Gateway (Kong/Envoy).
    private func applyHeaders(to request: inout URLRequest, withToken bearerToken: String? = nil) {
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        let token = bearerToken ?? anonKey
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("lectoria-ios/1.0", forHTTPHeaderField: "X-Client-Info")
    }

    /// Procesa y registra detalladamente los errores devueltos por Supabase Auth API.
    private func parseSupabaseError(from data: Data, response: HTTPURLResponse) -> NSError {
        let statusCode = response.statusCode
        let requestId = response.value(forHTTPHeaderField: "sb-request-id") ?? response.value(forHTTPHeaderField: "x-request-id") ?? "unknown_request_id"
        let headerErrorCode = response.value(forHTTPHeaderField: "x-sb-error-code") ?? "none"

        var jsonMsg: String? = nil
        var jsonErrorCode: String? = nil

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            jsonMsg = json["msg"] as? String ?? json["message"] as? String ?? json["error_description"] as? String
            jsonErrorCode = json["error_code"] as? String ?? json["code"] as? String
        }

        let message = jsonMsg ?? String(data: data, encoding: .utf8) ?? "Error de autenticación (\(statusCode))"
        let errorCode = jsonErrorCode ?? headerErrorCode

        logger.error("""
        ❌ [SupabaseAuth Error]
        • Status Code: \(statusCode)
        • SB-Request-ID: \(requestId)
        • Header Error Code: \(headerErrorCode)
        • JSON Error Code: \(errorCode)
        • Message: \(message)
        """)

        print("❌ [SupabaseAuth Diagnostic] Status: \(statusCode) | RequestID: \(requestId) | ErrorCode: \(errorCode) | Msg: \(message)")

        return NSError(domain: "SupabaseAuth", code: statusCode, userInfo: [
            NSLocalizedDescriptionKey: message,
            "errorCode": errorCode,
            "requestId": requestId,
            "statusCode": statusCode
        ])
    }

    /// Inicia sesión con Apple enviando el token de identidad (JWT) y nonce a Supabase.
    public func signInWithApple(identityToken: String, rawNonce: String?, email: String?, fullName: String?) async throws {
        let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=id_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyHeaders(to: &request)

        var body: [String: Any] = [
            "provider": "apple",
            "id_token": identityToken
        ]
        if let rawNonce {
            body["nonce"] = rawNonce
        }

        var metadata: [String: Any] = [:]
        if let fullName {
            metadata["full_name"] = fullName
        }
        if !metadata.isEmpty {
            body["options"] = ["user_metadata": metadata]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw parseSupabaseError(from: data, response: httpResponse)
        }

        let session = try JSONDecoder().decode(SupabaseSessionResponse.self, from: data)

        await MainActor.run {
            self.sessionToken = session.accessToken
            let profile = UserProfile(
                id: session.user.id,
                email: session.user.email ?? email,
                fullName: session.user.userMetadata?.fullName ?? fullName,
                createdAt: session.user.createdAt ?? Date()
            )
            self.currentUser = profile

            if let tokenData = session.accessToken.data(using: .utf8) {
                KeychainHelper.save(key: "sessionToken", data: tokenData)
            }
            if let profileData = try? JSONEncoder().encode(profile) {
                KeychainHelper.save(key: "userProfile", data: profileData)
            }
        }
    }

    /// Inicia sesión con Google enviando el ID token o access token a Supabase.
    public func signInWithGoogle(idToken: String, accessToken: String?) async throws {
        let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=id_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyHeaders(to: &request)

        var body: [String: Any] = [
            "provider": "google",
            "id_token": idToken
        ]
        if let accessToken {
            body["access_token"] = accessToken
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw parseSupabaseError(from: data, response: httpResponse)
        }

        let session = try JSONDecoder().decode(SupabaseSessionResponse.self, from: data)

        await MainActor.run {
            self.sessionToken = session.accessToken
            let profile = UserProfile(
                id: session.user.id,
                email: session.user.email,
                fullName: session.user.userMetadata?.fullName,
                createdAt: session.user.createdAt ?? Date()
            )
            self.currentUser = profile

            if let tokenData = session.accessToken.data(using: .utf8) {
                KeychainHelper.save(key: "sessionToken", data: tokenData)
            }
            if let profileData = try? JSONEncoder().encode(profile) {
                KeychainHelper.save(key: "userProfile", data: profileData)
            }
        }
    }

    /// Solicita el envío de un código OTP de un solo uso por correo electrónico a Supabase GoTrue `/auth/v1/otp`.
    public func sendOTPCode(to email: String) async throws {
        let url = URL(string: "\(supabaseURL)/auth/v1/otp")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyHeaders(to: &request)

        let body: [String: Any] = [
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            "create_user": true
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw parseSupabaseError(from: data, response: httpResponse)
        }
    }

    /// Verifica un código OTP enviado al correo mediante `/auth/v1/verify`.
    public func verifyOTPCode(email: String, code: String) async throws {
        let url = URL(string: "\(supabaseURL)/auth/v1/verify")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyHeaders(to: &request)

        let body: [String: Any] = [
            "type": "email",
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            "token": code.trimmingCharacters(in: .whitespacesAndNewlines)
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw parseSupabaseError(from: data, response: httpResponse)
        }

        let session = try JSONDecoder().decode(SupabaseSessionResponse.self, from: data)

        await MainActor.run {
            self.sessionToken = session.accessToken
            let profile = UserProfile(
                id: session.user.id,
                email: session.user.email ?? email,
                fullName: session.user.userMetadata?.fullName,
                createdAt: session.user.createdAt ?? Date()
            )
            self.currentUser = profile

            if let tokenData = session.accessToken.data(using: .utf8) {
                KeychainHelper.save(key: "sessionToken", data: tokenData)
            }
            if let profileData = try? JSONEncoder().encode(profile) {
                KeychainHelper.save(key: "userProfile", data: profileData)
            }
        }
    }

    /// Cierra sesión del usuario actual revocando el token del cliente.
    public func signOut() async throws {
        guard let token = sessionToken else { return }

        let url = URL(string: "\(supabaseURL)/auth/v1/logout")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyHeaders(to: &request, withToken: token)

        _ = try? await URLSession.shared.data(for: request)

        await MainActor.run {
            self.sessionToken = nil
            self.currentUser = nil
            KeychainHelper.delete(key: "sessionToken")
            KeychainHelper.delete(key: "userProfile")
        }
    }

    /// Elimina de forma definitiva la cuenta del usuario llamando al procedimiento almacenado de base de datos.
    public func deleteAccount() async throws {
        guard let token = sessionToken else { return }

        let url = URL(string: "\(supabaseURL)/rest/v1/rpc/delete_user_account")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyHeaders(to: &request, withToken: token)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw parseSupabaseError(from: data, response: httpResponse)
        }

        try await signOut()
    }
}

// MARK: - Decodable Networking Models

struct SupabaseSessionResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let user: SupabaseUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct SupabaseUser: Codable {
    let id: String
    let email: String?
    let createdAt: Date?
    let userMetadata: SupabaseUserMetadata?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case createdAt = "created_at"
        case userMetadata = "user_metadata"
    }
}

struct SupabaseUserMetadata: Codable {
    let fullName: String?

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
    }
}
