import Foundation
import Observation

// MARK: - MockAuthService

/// Implementación Mock de `AuthService` para previsualizaciones de SwiftUI y pruebas unitarias aisladas.
@Observable
public final class MockAuthService: AuthService, @unchecked Sendable {
    public var currentUser: UserProfile? = nil
    public var sessionToken: String? = nil
    public var supabaseURL: String = "https://qikgjqbqjlgoeuxtujiy.supabase.co"

    public var shouldFail = false
    public var shouldFailOTP = false

    public init(currentUser: UserProfile? = nil, sessionToken: String? = nil) {
        self.currentUser = currentUser
        self.sessionToken = sessionToken
    }

    public func signInWithApple(identityToken: String, rawNonce: String?, email: String?, fullName: String?) async throws {
        if shouldFail {
            throw NSError(domain: "MockAuth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Error simulado de autenticación con Apple"])
        }

        currentUser = UserProfile(
            id: "mock_user_apple_123",
            email: email ?? "apple_user@lectoria.app",
            fullName: fullName ?? "Usuario de Apple"
        )
        sessionToken = "mock_session_token_apple"
    }

    public func signInWithGoogle(idToken: String, accessToken: String?) async throws {
        if shouldFail {
            throw NSError(domain: "MockAuth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Error simulado de autenticación con Google"])
        }

        currentUser = UserProfile(
            id: "mock_user_google_456",
            email: "google_user@lectoria.app",
            fullName: "Usuario de Google"
        )
        sessionToken = "mock_session_token_google"
    }

    public func setSessionFromOAuth(accessToken: String, refreshToken: String?) async throws {
        if shouldFail {
            throw NSError(domain: "MockAuth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Error simulado de autenticación con Google OAuth"])
        }

        currentUser = UserProfile(
            id: "mock_user_google_oauth_789",
            email: "google_oauth_user@lectoria.app",
            fullName: "Usuario de Google OAuth"
        )
        sessionToken = accessToken
    }

    public func sendOTPCode(to email: String) async throws {
        if shouldFail || shouldFailOTP {
            throw NSError(domain: "MockAuth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Error simulado al enviar código OTP"])
        }
    }

    public func verifyOTPCode(email: String, code: String) async throws {
        if shouldFail || shouldFailOTP || code != "123456" {
            throw NSError(domain: "MockAuth", code: 400, userInfo: [NSLocalizedDescriptionKey: "El código de verificación es incorrecto."])
        }

        currentUser = UserProfile(
            id: "mock_user_otp_789",
            email: email,
            fullName: "Usuario de Correo"
        )
        sessionToken = "mock_session_token_otp"
    }

    public func signOut() async throws {
        currentUser = nil
        sessionToken = nil
    }

    public func deleteAccount() async throws {
        try await signOut()
    }
}
