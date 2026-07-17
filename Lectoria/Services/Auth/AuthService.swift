import Foundation

// MARK: - AuthService

/// Define el contrato para el servicio de autenticación y gestión de cuentas.
public protocol AuthService: AnyObject, Sendable {
    /// Perfil del usuario actualmente autenticado (nil si es un invitado).
    var currentUser: UserProfile? { get }
    
    /// Token JWT de la sesión activa de Supabase (nil si no hay sesión).
    var sessionToken: String? { get }
    
    /// Inicia sesión o registra un usuario con un token de identidad de Apple.
    func signInWithApple(identityToken: String, email: String?, fullName: String?) async throws
    
    /// Cierra la sesión del usuario actual.
    func signOut() async throws
    
    /// Elimina de forma definitiva la cuenta del usuario y sus datos asociados.
    func deleteAccount() async throws
}
