import Foundation
import SwiftUI
import Observation

// MARK: - InstitutionalAuthViewModel

/// ViewModel para la gestión del flujo de autenticación institucional.
/// Orquesta la máquina de estados, validaciones, envío de OTP, temporizador de reenvío y reclamo seguro por ticket.
@Observable
@MainActor
public final class InstitutionalAuthViewModel {
    // MARK: - Propiedades de Estado

    public var route: InstitutionalRoute = .email
    public var state: InstitutionalAccessState = .idle

    public var email: String = ""
    public var accessCode: String = ""
    public var otpCode: String = ""

    public var validatedInstitution: InstitutionInfo? = nil
    public var validation_ticket: String? = nil

    public var errorMessage: String? = nil
    public var showErrorAlert: Bool = false
    public var resendCountdown: Int = 0

    nonisolated(unsafe) private var timerTask: Task<Void, Never>? = nil

    // MARK: - Dependencias

    private let institutionService: any InstitutionService
    private let authService: any AuthService
    private let onGuestMigrate: @Sendable (String) async -> Void
    private let onSuccess: @Sendable () -> Void

    public init(
        institutionService: any InstitutionService,
        authService: any AuthService,
        onGuestMigrate: @escaping @Sendable (String) async -> Void,
        onSuccess: @escaping @Sendable () -> Void
    ) {
        self.institutionService = institutionService
        self.authService = authService
        self.onGuestMigrate = onGuestMigrate
        self.onSuccess = onSuccess
    }

    deinit {
        timerTask?.cancel()
    }

    // MARK: - Métodos de Navegación y Rutas

    public func selectRoute(_ newRoute: InstitutionalRoute) {
        guard route != newRoute else { return }
        route = newRoute
        errorMessage = nil
        showErrorAlert = false
        state = .idle
        if newRoute == .email {
            accessCode = ""
            validatedInstitution = nil
            validation_ticket = nil
        }
    }

    public func resetToInitialStep() {
        state = .idle
        otpCode = ""
        errorMessage = nil
        showErrorAlert = false
        stopResendTimer()
    }

    // MARK: - Flujo B: Validación de Código de Convenio

    public func validateAccessCode() async {
        let trimmedCode = accessCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmedCode.isEmpty else {
            handleError(.codeNotFound)
            return
        }

        errorMessage = nil
        showErrorAlert = false
        state = .validatingInstitution

        do {
            let institution = try await institutionService.inspectAccessCode(code: trimmedCode)
            self.validatedInstitution = institution
            self.state = .institutionValidated(institution)
        } catch let error as InstitutionalAuthError {
            handleError(error)
        } catch {
            handleError(.serviceError(message: error.localizedDescription))
        }
    }

    // MARK: - Flujo A y B: Validación de Correo y Envío de OTP

    public func validateEmailAndSendOTP() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard trimmedEmail.contains("@") && trimmedEmail.contains(".") else {
            handleError(.invalidEmail)
            return
        }

        errorMessage = nil
        showErrorAlert = false
        state = .sendingOTP

        do {
            if route == .code {
                // En el flujo de código, solicitamos el OTP a la Edge Function
                let cleanCode = accessCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                let result = try await institutionService.requestInstitutionalOTP(code: cleanCode, email: trimmedEmail)
                self.validation_ticket = result.validation_ticket
                self.validatedInstitution = result.institution
            } else {
                // En el flujo de dominio, validamos dominio local y llamamos a Supabase Auth directamente
                let institution = try await institutionService.validateDomain(email: trimmedEmail)
                self.validatedInstitution = institution
                try await authService.sendOTPCode(to: trimmedEmail)
            }

            startResendTimer()
            state = .awaitingOTP(email: trimmedEmail, institution: validatedInstitution)
        } catch let error as InstitutionalAuthError {
            handleError(error)
        } catch {
            handleError(.serviceError(message: error.localizedDescription))
        }
    }

    // MARK: - Verificación de OTP y Reclamo de Membresía

    public func verifyOTPAndLinkMembership() async {
        let trimmedOTP = otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard trimmedOTP.count == 6 else {
            handleError(.invalidOTP)
            return
        }

        errorMessage = nil
        showErrorAlert = false
        state = .verifyingOTP

        do {
            try await authService.verifyOTPCode(email: trimmedEmail, code: trimmedOTP)

            state = .linkingMembership

            if route == .code, let ticket = validation_ticket {
                try await institutionService.claimMembershipByTicket(ticket: ticket)
                print("✅ [DIAG-OTP] Membresía reclamada por ticket | membership_claimed: true")
            } else {
                try await institutionService.claimMembershipByDomain(email: trimmedEmail)
                print("✅ [DIAG-OTP] Membresía reclamada por dominio | membership_claimed: true")
            }

            if let user = authService.currentUser {
                await onGuestMigrate(user.id)
            }

            state = .authenticated
            stopResendTimer()
            print("🏛 [DIAG-OTP] Navegando a Biblioteca | navigation: success")
            onSuccess()
        } catch let error as InstitutionalAuthError {
            print("❌ [DIAG-OTP] InstitutionalAuthError: \(error.errorDescription ?? error.localizedDescription) | membership_claimed: false | navigation: false")
            handleError(error)
        } catch {
            print("❌ [DIAG-OTP] Error genérico: \(error.localizedDescription) | membership_claimed: false | navigation: false")
            let errorMsg = error.localizedDescription.lowercased()
            if errorMsg.contains("expired") || errorMsg.contains("vencido") {
                handleError(.otpExpired)
            } else if errorMsg.contains("invalid") || errorMsg.contains("incorrecto") {
                handleError(.invalidOTP)
            } else {
                handleError(.serviceError(message: error.localizedDescription))
            }
        }
    }

    // MARK: - Reenvío de OTP

    public func resendOTP() async {
        guard resendCountdown == 0 else { return }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedEmail.isEmpty else { return }

        state = .sendingOTP
        do {
            if route == .code {
                let cleanCode = accessCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                let result = try await institutionService.requestInstitutionalOTP(code: cleanCode, email: trimmedEmail)
                self.validation_ticket = result.validation_ticket
            } else {
                try await authService.sendOTPCode(to: trimmedEmail)
            }
            startResendTimer()
            state = .awaitingOTP(email: trimmedEmail, institution: validatedInstitution)
        } catch {
            handleError(.serviceError(message: error.localizedDescription))
        }
    }

    // MARK: - Helpers Privados

    private func startResendTimer() {
        stopResendTimer()
        resendCountdown = 30
        timerTask = Task { @MainActor [weak self] in
            while let self = self, self.resendCountdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self.resendCountdown -= 1
            }
        }
    }

    private func stopResendTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func handleError(_ error: InstitutionalAuthError) {
        let message = error.errorDescription ?? "Ocurrió un error inesperado."
        self.errorMessage = message
        self.showErrorAlert = true
        self.state = .failed(error)
    }
}
