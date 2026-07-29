import Foundation

// MARK: - LocalAIAvailability

/// Estado de disponibilidad de los servicios de IA y procesamiento de lenguaje nativo en el dispositivo.
public enum LocalAIAvailability: Equatable, Sendable {
    case available
    case unsupportedHardware
    case unsupportedOS
    case modelUnavailable
    case languageUnsupported
    case temporarilyUnavailable

    public var isAvailable: Bool {
        self == .available
    }

    public var userMessage: String {
        switch self {
        case .available:
            return String(localized: "IA local activa y funcionando en tu dispositivo sin conexión a internet.", comment: "AI status message")
        case .unsupportedHardware:
            return String(localized: "Tu dispositivo no cumple con los requisitos de hardware para IA local (requiere iPhone 11 o posterior).", comment: "AI status message")
        case .unsupportedOS:
            return String(localized: "La IA local requiere iOS 17 o posterior.", comment: "AI status message")
        case .modelUnavailable:
            return String(localized: "El modelo lingüístico local no está instalado en tu dispositivo.", comment: "AI status message")
        case .languageUnsupported:
            return String(localized: "El idioma del documento no está soportado por la IA local.", comment: "AI status message")
        case .temporarilyUnavailable:
            return String(localized: "La IA local no está disponible temporalmente.", comment: "AI status message")
        }
    }
}

// MARK: - AIDisclaimer

/// Advertencia legal obligatoria exigida por la especificación maestra de Lectoría.
public enum AIDisclaimer {
    public static let text = String(
        localized: "Las funciones de inteligencia artificial pueden generar errores. Verifica la información importante. Los resúmenes no reemplazan la lectura del documento y las traducciones pueden requerir revisión.",
        comment: "Mandatory AI legal disclaimer"
    )
}
