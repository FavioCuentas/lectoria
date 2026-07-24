import Foundation

// MARK: - AnalyticsService

/// Protocolo principal para la captura y envío asíncrono por lotes de eventos de analítica de producto en Lectoria.
public protocol AnalyticsService: Sendable {
    /// Identificador de sesión único generado al iniciar la app.
    var currentSessionID: UUID { get }

    /// Registra un evento con sus propiedades sanitizadas.
    func track(_ name: AnalyticsEventName, properties: [String: Any])

    /// Despacha manualmente la cola local de eventos acumulados a Supabase.
    func flush() async
}

extension AnalyticsService {
    public func track(_ name: AnalyticsEventName) {
        track(name, properties: [:])
    }
}
