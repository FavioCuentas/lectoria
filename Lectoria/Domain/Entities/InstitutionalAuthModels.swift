import Foundation

// MARK: - InstitutionalRoute

/// Representa las dos rutas posibles del flujo de acceso institucional.
public enum InstitutionalRoute: String, Codable, Sendable, CaseIterable, Identifiable {
    case email
    case code

    public var id: String { rawValue }
}

// MARK: - InstitutionInfo

/// Información pública de una institución identificada.
public struct InstitutionInfo: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let name: String
    public let slug: String
    public let planType: String

    public init(id: UUID, name: String, slug: String, planType: String = "institutional") {
        self.id = id
        self.name = name
        self.slug = slug
        self.planType = planType
    }
}

// MARK: - InstitutionalAccessState

/// Estados explícitos de la máquina de estados de acceso institucional.
public enum InstitutionalAccessState: Equatable, Sendable {
    case idle
    case validatingInstitution
    case institutionValidated(InstitutionInfo)
    case sendingOTP
    case awaitingOTP(email: String, institution: InstitutionInfo?)
    case verifyingOTP
    case linkingMembership
    case authenticated
    case failed(InstitutionalAuthError)
}

// MARK: - InstitutionalAuthError

/// Mapeo de errores técnicos a mensajes comprensibles en español.
public enum InstitutionalAuthError: Error, Equatable, Sendable, LocalizedError {
    case codeNotFound
    case codeExpired
    case codeDeactivated
    case codeMaxUsesReached
    case domainUnauthorized(domain: String)
    case invalidEmail
    case invalidOTP
    case otpExpired
    case tooManyRequests
    case networkError
    case serviceError(message: String)

    public var errorDescription: String? {
        switch self {
        case .codeNotFound:
            return String(localized: "El código de acceso ingresado no es válido. Revisa el código proporcionado por tu institución.", comment: "Error code not found")
        case .codeExpired:
            return String(localized: "El código de acceso ha vencido. Contacta al administrador de tu institución.", comment: "Error code expired")
        case .codeDeactivated:
            return String(localized: "El código de acceso se encuentra desactivado temporalmente.", comment: "Error code deactivated")
        case .codeMaxUsesReached:
            return String(localized: "Este código de acceso ha alcanzado el límite máximo de registros permitidos.", comment: "Error max uses reached")
        case .domainUnauthorized(let domain):
            return String(localized: "El dominio (\(domain)) no pertenece a una institución con convenio activo.", comment: "Error domain unauthorized")
        case .invalidEmail:
            return String(localized: "Por favor ingresa un correo electrónico institucional válido (ejemplo: usuario@universidad.edu).", comment: "Error invalid email")
        case .invalidOTP:
            return String(localized: "El código de verificación es incorrecto. Por favor verifica los 6 dígitos.", comment: "Error invalid OTP")
        case .otpExpired:
            return String(localized: "El código de verificación ha caducado. Solicita un nuevo código de verificación.", comment: "Error OTP expired")
        case .tooManyRequests:
            return String(localized: "Demasiados intentos en poco tiempo. Por favor espera un momento e inténtalo de nuevo.", comment: "Error too many requests")
        case .networkError:
            return String(localized: "Error de conexión. Comprueba tu conexión a Internet e inténtalo nuevamente.", comment: "Error network failure")
        case .serviceError(let message):
            return message
        }
    }
}
