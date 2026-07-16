import Foundation

// MARK: - AppError

/// Errores tipados de la aplicación con mensajes amigables para el usuario.
///
/// Cada categoría agrupa errores relacionados. Todos los errores definen
/// un título, mensaje localizado y acción de recuperación sugerida.
enum AppError: LocalizedError, Sendable {

    // MARK: - Importación

    case unsupportedFormat(fileExtension: String)
    case corruptedFile(fileName: String)
    case duplicatePublication(existingID: UUID)
    case insufficientStorage
    case accessDenied(fileName: String)
    case fileTooLarge(sizeMB: Int)

    // MARK: - Archivo

    case fileNotFound(path: String)
    case fileReadError(underlying: String)

    // MARK: - Renderizado

    case renderingFailed(format: PublicationType)
    case unsupportedContent

    // MARK: - Persistencia

    case saveFailed(underlying: String)
    case loadFailed(underlying: String)
    case migrationFailed

    // MARK: - Red

    case networkUnavailable
    case serverError(statusCode: Int)
    case timeout

    // MARK: - Autenticación

    case authenticationRequired
    case sessionExpired

    // MARK: - Sincronización

    case syncConflict
    case syncFailed(underlying: String)

    // MARK: - IA

    case aiQuotaExceeded
    case aiConsentRequired
    case aiServiceUnavailable

    // MARK: - Suscripción

    case purchaseFailed(underlying: String)
    case subscriptionExpired
    case featureRequiresPremium

    // MARK: - Permisos

    case permissionDenied(resource: String)

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            String(localized: "El formato .\(ext) no es compatible.",
                   comment: "Error: unsupported file format")
        case .corruptedFile(let name):
            String(localized: "El archivo \"\(name)\" está dañado o no se puede abrir.",
                   comment: "Error: corrupted file")
        case .duplicatePublication:
            String(localized: "Este documento ya existe en tu biblioteca.",
                   comment: "Error: duplicate publication")
        case .insufficientStorage:
            String(localized: "No hay suficiente espacio en el dispositivo.",
                   comment: "Error: insufficient storage")
        case .accessDenied(let name):
            String(localized: "No se pudo acceder al archivo \"\(name)\".",
                   comment: "Error: access denied")
        case .fileTooLarge(let sizeMB):
            String(localized: "El archivo supera el tamaño máximo permitido (\(sizeMB) MB).",
                   comment: "Error: file too large")
        case .fileNotFound:
            String(localized: "El archivo no se encontró.",
                   comment: "Error: file not found")
        case .fileReadError:
            String(localized: "Error al leer el archivo.",
                   comment: "Error: file read error")
        case .renderingFailed(let format):
            String(localized: "No se pudo mostrar el contenido \(format.displayName).",
                   comment: "Error: rendering failed")
        case .unsupportedContent:
            String(localized: "El contenido no es compatible.",
                   comment: "Error: unsupported content")
        case .saveFailed:
            String(localized: "No se pudieron guardar los cambios.",
                   comment: "Error: save failed")
        case .loadFailed:
            String(localized: "No se pudieron cargar los datos.",
                   comment: "Error: load failed")
        case .migrationFailed:
            String(localized: "Error al actualizar la base de datos.",
                   comment: "Error: migration failed")
        case .networkUnavailable:
            String(localized: "Sin conexión a internet.",
                   comment: "Error: network unavailable")
        case .serverError(let code):
            String(localized: "Error del servidor (código \(code)).",
                   comment: "Error: server error")
        case .timeout:
            String(localized: "La solicitud tardó demasiado.",
                   comment: "Error: timeout")
        case .authenticationRequired:
            String(localized: "Inicia sesión para continuar.",
                   comment: "Error: auth required")
        case .sessionExpired:
            String(localized: "Tu sesión ha expirado. Inicia sesión de nuevo.",
                   comment: "Error: session expired")
        case .syncConflict:
            String(localized: "Hay un conflicto de sincronización.",
                   comment: "Error: sync conflict")
        case .syncFailed:
            String(localized: "No se pudo sincronizar.",
                   comment: "Error: sync failed")
        case .aiQuotaExceeded:
            String(localized: "Has alcanzado el límite de acciones de IA este mes.",
                   comment: "Error: AI quota exceeded")
        case .aiConsentRequired:
            String(localized: "Debes autorizar el uso de IA antes de continuar.",
                   comment: "Error: AI consent required")
        case .aiServiceUnavailable:
            String(localized: "El servicio de IA no está disponible en este momento.",
                   comment: "Error: AI service unavailable")
        case .purchaseFailed:
            String(localized: "No se pudo completar la compra.",
                   comment: "Error: purchase failed")
        case .subscriptionExpired:
            String(localized: "Tu suscripción ha expirado.",
                   comment: "Error: subscription expired")
        case .featureRequiresPremium:
            String(localized: "Esta función requiere el plan Premium.",
                   comment: "Error: feature requires premium")
        case .permissionDenied(let resource):
            String(localized: "Permiso denegado para \(resource).",
                   comment: "Error: permission denied")
        }
    }

    /// Título breve para mostrar en alertas.
    var alertTitle: String {
        switch self {
        case .unsupportedFormat, .corruptedFile, .duplicatePublication,
             .insufficientStorage, .accessDenied, .fileTooLarge:
            String(localized: "Error de importación", comment: "Alert title for import errors")
        case .fileNotFound, .fileReadError:
            String(localized: "Error de archivo", comment: "Alert title for file errors")
        case .renderingFailed, .unsupportedContent:
            String(localized: "Error de visualización", comment: "Alert title for rendering errors")
        case .saveFailed, .loadFailed, .migrationFailed:
            String(localized: "Error de datos", comment: "Alert title for persistence errors")
        case .networkUnavailable, .serverError, .timeout:
            String(localized: "Error de conexión", comment: "Alert title for network errors")
        case .authenticationRequired, .sessionExpired:
            String(localized: "Autenticación", comment: "Alert title for auth errors")
        case .syncConflict, .syncFailed:
            String(localized: "Sincronización", comment: "Alert title for sync errors")
        case .aiQuotaExceeded, .aiConsentRequired, .aiServiceUnavailable:
            String(localized: "Inteligencia artificial", comment: "Alert title for AI errors")
        case .purchaseFailed, .subscriptionExpired, .featureRequiresPremium:
            String(localized: "Suscripción", comment: "Alert title for subscription errors")
        case .permissionDenied:
            String(localized: "Permisos", comment: "Alert title for permission errors")
        }
    }

    /// Indica si el error debe registrarse para diagnóstico.
    var shouldLog: Bool {
        switch self {
        case .duplicatePublication, .featureRequiresPremium,
             .authenticationRequired, .aiConsentRequired:
            false
        default:
            true
        }
    }
}
