import Foundation

// MARK: - AnalyticsEvent

/// Eventos de analítica permitidos, sin datos personales.
///
/// Siguiendo el principio de privacidad primero, estos eventos solo
/// registran categorías y acciones, nunca contenido de documentos,
/// notas, títulos reales ni nombres de archivo.
enum AnalyticsEvent: Sendable {
    case onboardingCompleted
    case importStarted(format: PublicationType)
    case importSucceeded(format: PublicationType)
    case importFailed(format: PublicationType, errorCode: String)
    case publicationOpened(format: PublicationType)
    case readingSessionCompleted(durationSeconds: Int)
    case highlightCreated
    case noteCreated
    case aiActionRequested(action: String)
    case aiActionCompleted(action: String)
    case paywallViewed
    case purchaseCompleted(productID: String)
    case purchaseRestored
}

// MARK: - AnalyticsTracking

/// Protocolo abstracto para el servicio de analítica.
///
/// La implementación concreta se inyecta en el environment.
/// En desarrollo se usa una implementación que imprime en consola.
/// En producción se usará un proveedor respetuoso con la privacidad.
protocol AnalyticsTracking: Sendable {
    /// Registra un evento de analítica.
    func track(_ event: AnalyticsEvent)
}

// MARK: - ConsoleAnalytics

#if DEBUG
/// Implementación de desarrollo que imprime eventos en consola.
struct ConsoleAnalytics: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {
        print("[Analytics] \(event)")
    }
}
#endif
