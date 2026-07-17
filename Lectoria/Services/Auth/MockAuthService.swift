import Foundation
import Observation

// MARK: - MockAuthService

/// Implementación Mock de `AuthService` para previsualizaciones de SwiftUI y pruebas unitarias aisladas.
@Observable
public final class MockAuthService: AuthService, @unchecked Sendable {
    public var currentUser: UserProfile? = nil
    public var sessionToken: String? = nil
    
    public var shouldFail = false
    
    public init(currentUser: UserProfile? = nil, sessionToken: String? = nil) {
        self.currentUser = currentUser
        self.sessionToken = sessionToken
    }
    
    public func signInWithApple(identityToken: String, email: String?, fullName: String?) async throws {
        if shouldFail {
            throw NSError(domain: "MockAuth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Error simulado de autenticación"])
        }
        
        currentUser = UserProfile(
            id: "mock_user_123",
            email: email ?? "mock@lectoria.app",
            fullName: fullName ?? "Usuario de Prueba"
        )
        sessionToken = "mock_session_token_xyz"
    }
    
    public func signOut() async throws {
        currentUser = nil
        sessionToken = nil
    }
    
    public func deleteAccount() async throws {
        try await signOut()
    }
}
