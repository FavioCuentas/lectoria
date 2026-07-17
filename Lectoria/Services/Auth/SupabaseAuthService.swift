import Foundation
import Observation

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
    
    /// Inicia sesión con Apple enviando el token de identidad (JWT) a Supabase.
    public func signInWithApple(identityToken: String, email: String?, fullName: String?) async throws {
        let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=id_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "provider": "apple",
            "id_token": identityToken
        ]
        
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
            let errorMsg = String(data: data, encoding: .utf8) ?? "Error desconocido en Supabase Auth"
            throw NSError(domain: "SupabaseAuth", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
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
            
            // Persistir tokens en el Keychain
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
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Intentar llamada (si falla, cerramos sesión localmente de todas formas)
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
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Error al eliminar cuenta en Supabase"
            throw NSError(domain: "SupabaseAuth", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        try await signOut()
    }
}

// MARK: - Decodable Networking Models

struct SupabaseSessionResponse: Codable {
    let accessToken: String
    let refreshToken: String
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
