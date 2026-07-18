import Foundation

// MARK: - SearchResult

/// Resultado de una búsqueda dentro de una publicación.
struct SearchResult: Identifiable, Sendable {
    let id: UUID
    let text: String
    let contextBefore: String
    let contextAfter: String
    let chapterTitle: String?
    let locationData: Data // Serialized location, format-specific

    init(
        id: UUID = UUID(),
        text: String,
        contextBefore: String = "",
        contextAfter: String = "",
        chapterTitle: String? = nil,
        locationData: Data = Data()
    ) {
        self.id = id
        self.text = text
        self.contextBefore = contextBefore
        self.contextAfter = contextAfter
        self.chapterTitle = chapterTitle
        self.locationData = locationData
    }
}

// MARK: - TOCItem

/// Elemento del índice de contenidos de una publicación.
struct TOCItem: Identifiable, Sendable {
    let id: UUID
    let title: String
    let level: Int
    let locationData: Data
    let children: [TOCItem]

    init(
        id: UUID = UUID(),
        title: String,
        level: Int = 0,
        locationData: Data = Data(),
        children: [TOCItem] = []
    ) {
        self.id = id
        self.title = title
        self.level = level
        self.locationData = locationData
        self.children = children
    }
}

// MARK: - PublicationEngine

/// Protocolo base para los motores de renderizado de publicaciones.
///
/// Cada formato (EPUB, PDF, TXT/Markdown) implementa este protocolo
/// a través de un adaptador concreto. El tipo asociado `Location`
/// permite que cada motor defina su propia representación de posición.
///
/// Implementaciones previstas:
/// - `EPUBReaderAdapter` (Readium, Fase 3)
/// - `PDFReaderAdapter` (PDFKit, Fase 4)
/// - `TextReaderAdapter` (nativo, Fase 5)
@MainActor
protocol PublicationEngine<Location>: Sendable {
    /// Tipo que representa una posición dentro de la publicación.
    associatedtype Location: Codable & Sendable

    /// Abre una publicación para lectura.
    func open(publication: PublicationRecord) async throws

    /// Cierra la publicación actual y libera recursos.
    func close() async

    /// Obtiene la ubicación actual de lectura.
    func currentLocation() async -> Location?

    /// Navega a una ubicación específica.
    func go(to location: Location) async throws

    /// Busca texto dentro de la publicación abierta.
    func search(_ query: String) async throws -> [SearchResult]

    /// Obtiene la tabla de contenidos.
    func tableOfContents() async throws -> [TOCItem]
}

// MARK: - ReaderSelection

/// Representa una selección de texto realizada por el usuario en el lector.
struct ReaderSelection: Sendable {
    let text: String
    let contextBefore: String
    let contextAfter: String
    let locationData: Data
    let chapterTitle: String?
}

// MARK: - AnnotationAnchor

/// Ancla persistente para asociar una anotación a una posición en el documento.
struct AnnotationAnchor: Codable, Sendable {
    let publicationID: UUID
    let publicationType: PublicationType
    let locationData: Data
    let selectedText: String
    let contextBefore: String
    let contextAfter: String
}

// MARK: - AnnotationAnchoring

/// Protocolo para crear y resolver anclas de anotaciones.
///
/// Cada motor de lectura debe implementar este protocolo para
/// vincular anotaciones a posiciones estables en el documento.
@MainActor
protocol AnnotationAnchoring: Sendable {
    /// Crea un ancla a partir de una selección del usuario.
    func createAnchor(from selection: ReaderSelection) async throws -> AnnotationAnchor

    /// Intenta resolver un ancla previamente guardada a datos de presentación.
    func resolve(anchor: AnnotationAnchor) async throws -> ResolvedAnnotation?
}

// MARK: - ResolvedAnnotation

/// Resultado de resolver un ancla: contiene la información necesaria
/// para mostrar y navegar a la anotación en el documento.
struct ResolvedAnnotation: Sendable {
    let text: String
    let locationData: Data
    let isExactMatch: Bool
}
