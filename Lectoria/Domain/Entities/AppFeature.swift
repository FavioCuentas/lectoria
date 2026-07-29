import Foundation

// MARK: - AppFeature

/// Funciones del sistema sujetas a evaluación de permisos y límites comerciales.
public enum AppFeature: Sendable, Hashable {
    /// Importación de un nuevo documento según su formato
    case importDocument(format: PublicationType)

    /// Verificación de límite de documentos activos
    case activeDocumentCount(currentActive: Int)

    /// Creación de destacados/resaltados
    case createHighlight

    /// Creación de notas
    case createNote

    /// Exportación avanzada de notas y resúmenes
    case exportAdvanced

    /// Visualización de estadísticas avanzadas de lectura
    case viewAdvancedStatistics

    /// Uso de Inteligencia Artificial local
    case useLocalAI

    /// Uso de Traducción local Premium
    case useLocalTranslation

    /// Administración de dispositivos sincronizados
    case manageDevices

    /// Acceso a la Biblioteca Institucional
    case accessInstitutionalLibrary
}
