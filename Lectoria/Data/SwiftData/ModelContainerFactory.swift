import Foundation
import SwiftData

// MARK: - ModelContainerFactory

/// Fábrica encargada de crear y configurar el contenedor (`ModelContainer`) de SwiftData.
///
/// Soporta configuración persistente en disco (producción) o volátil en memoria (para pruebas y previews).
public enum ModelContainerFactory {
    /// Crea un `ModelContainer` configurado con todas las entidades de la aplicación.
    /// - Parameter isStoredInMemoryOnly: Si es `true`, los datos se guardarán únicamente en memoria.
    /// - Returns: El contenedor configurado.
    @MainActor
    public static func create(isStoredInMemoryOnly: Bool = false) -> ModelContainer {
        let schema = Schema([
            PublicationModel.self,
            ReadingProgressModel.self,
            BookmarkModel.self,
            HighlightModel.self,
            NoteModel.self,
            ReadingSessionModel.self,
            AIUsageModel.self,
            SubscriptionEntitlementModel.self
        ])
        
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("No se pudo inicializar el ModelContainer de SwiftData: \(error.localizedDescription)")
        }
    }
}
