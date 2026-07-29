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
    public private(set) var refreshToken: String? = nil
    public private(set) var sessionExpiresAt: Date? = nil

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

            if let refreshData = KeychainHelper.load(key: "refreshToken"),
               let rToken = String(data: refreshData, encoding: .utf8) {
                self.refreshToken = rToken
            }

            if let expiresData = KeychainHelper.load(key: "sessionExpiresAt"),
               let expiresStr = String(data: expiresData, encoding: .utf8),
               let timeInterval = Double(expiresStr) {
                self.sessionExpiresAt = Date(timeIntervalSince1970: timeInterval)
            }

            if let profileData = KeychainHelper.load(key: "userProfile"),
               let profile = try? JSONDecoder().decode(UserProfile.self, from: profileData) {
                self.currentUser = profile
            }
        }
    }

    /// JSONDecoder preconfigurado para parsear respuestas de Supabase.
    /// Supabase devuelve fechas como strings ISO 8601 (ej. "2026-07-29T12:00:00Z");
    /// sin esta estrategia, `user.created_at` lanza "data couldn't be read" al decodificar.
    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
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

    /// Procesa y almacena la respuesta completa de sesión de Supabase Auth (access_token, refresh_token, expiración y perfil).
    @MainActor
    private func handleSessionResponse(_ session: SupabaseSessionResponse, defaultEmail: String? = nil, defaultFullName: String? = nil) {
        self.sessionToken = session.accessToken
        if let refreshToken = session.refreshToken {
            self.refreshToken = refreshToken
        }

        let calculatedExpiresAt: Date
        if let expiresAtInt = session.expiresAt {
            calculatedExpiresAt = Date(timeIntervalSince1970: TimeInterval(expiresAtInt))
        } else if let expiresIn = session.expiresIn {
            calculatedExpiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        } else {
            calculatedExpiresAt = Date().addingTimeInterval(3600)
        }
        self.sessionExpiresAt = calculatedExpiresAt

        let profile = UserProfile(
            id: session.user.id,
            email: session.user.email ?? defaultEmail,
            fullName: session.user.userMetadata?.fullName ?? defaultFullName,
            createdAt: session.user.createdAt ?? Date()
        )
        self.currentUser = profile

        // Persistir en Keychain
        if let tokenData = session.accessToken.data(using: .utf8) {
            KeychainHelper.save(key: "sessionToken", data: tokenData)
        }
        if let rToken = session.refreshToken, let refreshData = rToken.data(using: .utf8) {
            KeychainHelper.save(key: "refreshToken", data: refreshData)
        }
        let expiresStr = String(calculatedExpiresAt.timeIntervalSince1970)
        if let expiresData = expiresStr.data(using: .utf8) {
            KeychainHelper.save(key: "sessionExpiresAt", data: expiresData)
        }
        if let profileData = try? JSONEncoder().encode(profile) {
            KeychainHelper.save(key: "userProfile", data: profileData)
        }
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

    /// Refresca la sesión activa de Supabase utilizando el refresh token.
    public func refreshSession() async throws {
        guard let currentRefreshToken = refreshToken else {
            throw NSError(domain: "SupabaseAuth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No existe refresh token activo para renovar sesión."])
        }

        let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=refresh_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyHeaders(to: &request)

        let body: [String: Any] = [
            "refresh_token": currentRefreshToken
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw parseSupabaseError(from: data, response: httpResponse)
        }

        let session = try makeDecoder().decode(SupabaseSessionResponse.self, from: data)
        await handleSessionResponse(session)
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

        let session = try makeDecoder().decode(SupabaseSessionResponse.self, from: data)
        await handleSessionResponse(session, defaultEmail: email, defaultFullName: fullName)
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

        let session = try makeDecoder().decode(SupabaseSessionResponse.self, from: data)
        await handleSessionResponse(session)
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
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = URL(string: "\(supabaseURL)/auth/v1/verify")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyHeaders(to: &request)

        // [DIAG-OTP] Tipo enviado a /auth/v1/verify
        // "email" es el tipo correcto para verificar un OTP de 6 dígitos enviado por /auth/v1/otp.
        // "magiclink" se reserva para verificar clics en enlaces mágicos, no códigos numéricos.
        let otpType = "email"
        let body: [String: Any] = [
            "type": otpType,
            "email": cleanEmail,
            "token": cleanCode
        ]

        print("🔍 [DIAG-OTP] Sending verify request | type: \(otpType) | endpoint: /auth/v1/verify")
        logger.info("🔍 [DIAG-OTP] Sending verify request | type: \(otpType)")

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [DIAG-OTP] No HTTP response received")
            throw URLError(.badServerResponse)
        }

        let statusCode = httpResponse.statusCode
        print("📡 [DIAG-OTP] HTTP status: \(statusCode)")
        logger.info("📡 [DIAG-OTP] HTTP status: \(statusCode)")

        guard (200...299).contains(statusCode) else {
            // Extraer error_code para el diagnóstico
            var errorCode = "none"
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                errorCode = json["error_code"] as? String ?? json["code"] as? String ?? "none"
            }
            print("❌ [DIAG-OTP] Verification failed | status: \(statusCode) | error_code: \(errorCode)")
            logger.error("❌ [DIAG-OTP] Verification failed | status: \(statusCode) | error_code: \(errorCode)")
            throw parseSupabaseError(from: data, response: httpResponse)
        }

        do {
            let session = try makeDecoder().decode(SupabaseSessionResponse.self, from: data)
            let sessionCreated = !session.accessToken.isEmpty
            print("✅ [DIAG-OTP] Verification succeeded | status: \(statusCode) | session_created: \(sessionCreated)")
            logger.info("✅ [DIAG-OTP] Verification succeeded | status: \(statusCode) | session_created: \(sessionCreated)")
            await handleSessionResponse(session, defaultEmail: cleanEmail)
        } catch let decodeError {
            // Log seguro: no registra tokens, solo el tipo de error de decodificación
            let errorDesc = decodeError.localizedDescription
            print("❌ [DIAG-OTP] JSON decode failed after \(statusCode) | error: \(errorDesc)")
            logger.error("❌ [DIAG-OTP] JSON decode failed | status: \(statusCode) | decode_error: \(errorDesc)")
            throw decodeError
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
            self.refreshToken = nil
            self.sessionExpiresAt = nil
            self.currentUser = nil
            KeychainHelper.delete(key: "sessionToken")
            KeychainHelper.delete(key: "refreshToken")
            KeychainHelper.delete(key: "sessionExpiresAt")
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
    let expiresIn: Int?
    let expiresAt: Int?
    let tokenType: String?
    let user: SupabaseUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case expiresAt = "expires_at"
        case tokenType = "token_type"
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
