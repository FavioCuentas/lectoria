import Foundation

// MARK: - SyncService

/// Contrato para el motor de sincronización offline-first de Lectoria.
public protocol SyncService: AnyObject, Sendable {
    /// Indica si hay un proceso de sincronización activo actualmente.
    var isSyncing: Bool { get }
    
    /// Retorna la marca de tiempo de la última sincronización completa y exitosa.
    var lastSyncedAt: Date? { get }
    
    /// Ejecuta una sincronización bidireccional completa (subida de cola local y bajada de novedades).
    func syncAll() async throws
    
    /// Ejecuta la sincronización inicial tras iniciar sesión. Descarga todos los datos de la nube
    /// y realiza una fusión inteligente con los datos locales existentes.
    func performInitialSync() async throws
}
