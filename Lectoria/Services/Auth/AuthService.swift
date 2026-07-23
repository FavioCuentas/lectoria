import Foundation

// MARK: - AuthService

/// Define el contrato para el servicio de autenticación y gestión de cuentas de Lectoria.
public protocol AuthService: AnyObject, Sendable {
    /// Perfil del usuario actualmente autenticado (nil si es un invitado).
    var currentUser: UserProfile? { get }

    /// Token JWT de la sesión activa de Supabase (nil si no hay sesión).
    var sessionToken: String? { get }

    /// Inicia sesión o registra un usuario con un token de identidad de Apple y nonce opcional.
    func signInWithApple(identityToken: String, rawNonce: String?, email: String?, fullName: String?) async throws

    /// Inicia sesión con Google OAuth 2.0 enviando el ID Token o Access Token a Supabase.
    func signInWithGoogle(idToken: String, accessToken: String?) async throws

    /// Envia un código OTP de un solo uso por correo electrónico.
    func sendOTPCode(to email: String) async throws

    /// Verifica un código OTP enviado al correo del usuario y establece la sesión.
    func verifyOTPCode(email: String, code: String) async throws

    /// Cierra la sesión del usuario actual.
    func signOut() async throws

    /// Elimina de forma definitiva la cuenta del usuario y sus datos asociados.
    func deleteAccount() async throws
}

// MARK: - Conveniencias por defecto

extension AuthService {
    public func signInWithApple(identityToken: String, email: String?, fullName: String?) async throws {
        try await signInWithApple(identityToken: identityToken, rawNonce: nil, email: email, fullName: fullName)
    }
}
