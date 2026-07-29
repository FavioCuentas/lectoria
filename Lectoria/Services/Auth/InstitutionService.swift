import Foundation

// MARK: - AccessCodeValidationResult

public struct AccessCodeValidationResult: Sendable, Equatable {
    public let validation_ticket: String
    public let institution: InstitutionInfo

    public init(validation_ticket: String, institution: InstitutionInfo) {
        self.validation_ticket = validation_ticket
        self.institution = institution
    }
}

// MARK: - InstitutionService Protocol

/// Define el contrato para la validación de dominios, códigos de convenio y gestión de membresías institucionales.
public protocol InstitutionService: Sendable {
    /// Consulta si el dominio del correo pertenece a una institución activa y devuelve su información.
    func validateDomain(email: String) async throws -> InstitutionInfo

    /// Inspecciona si un código de acceso es válido/activo sin generar ticket ni enviar OTP.
    func inspectAccessCode(code: String) async throws -> InstitutionInfo

    /// Solicita el envío de OTP asociándolo a un código de convenio y un correo institucional, obteniendo un ticket activado.
    func requestInstitutionalOTP(code: String, email: String) async throws -> AccessCodeValidationResult

    /// Reclama la membresía de la institución mediante comprobación de dominio autorizado (Ruta A).
    func claimMembershipByDomain(email: String) async throws

    /// Reclama la membresía de la institución mediante un validation_ticket seguro de un solo uso (Ruta B).
    func claimMembershipByTicket(ticket: String) async throws
}
