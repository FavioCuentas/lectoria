import Foundation
import SwiftData

// MARK: - Resultados

/// Nota o destacado que coincide con la búsqueda global.
struct AnnotationHit: Sendable, Equatable, Identifiable {
    enum Kind: Sendable, Hashable { case note, highlight }

    let id: UUID
    let publicationID: UUID
    let kind: Kind
    let text: String
    /// Ubicación guardada (JSON de PDFLocation, TextLocation o EPUBLocation), si la hay.
    let anchor: String?
}

/// Resultados de la búsqueda global, agrupados como se muestran en la Biblioteca.
struct GlobalSearchResults: Sendable, Equatable {
    var titleMatches: [UUID] = []
    var documents: [DocumentHits] = []
    var annotations: [AnnotationHit] = []

    var isEmpty: Bool { titleMatches.isEmpty && documents.isEmpty && annotations.isEmpty }
}

/// Resultado de contenido que se quiere abrir: el lector busca `query` y se coloca
/// en la primera coincidencia dentro de `scope` (página, capítulo, bloque o diapositiva).
struct ContentSearchTarget: Hashable, Identifiable {
    let publication: PublicationRecord
    let query: String
    let scope: String
    var id: String { "\(publication.id)|\(scope)|\(query)" }
}

/// Nota o destacado que se quiere abrir en su ubicación (si la tiene).
struct AnnotationOpenTarget: Hashable, Identifiable {
    let publication: PublicationRecord
    let anchor: String?
    var id: String { "\(publication.id)|\(anchor ?? "")" }
}

// MARK: - GlobalSearchService

/// Busca en toda la biblioteca: títulos y autores, contenido indexado, notas y destacados.
/// Todo ignora mayúsculas y acentos.
@MainActor
final class GlobalSearchService {
    static let maxAnnotationsPerKind = 30

    private let store: SearchIndexStore?
    private let container: ModelContainer

    init(store: SearchIndexStore?, container: ModelContainer) {
        self.store = store
        self.container = container
    }

    func search(_ query: String, publications: [PublicationRecord]) async -> GlobalSearchResults {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return GlobalSearchResults() }

        let titleMatches = publications
            .filter { $0.title.localizedStandardContains(trimmed) || ($0.author?.localizedStandardContains(trimmed) ?? false) }
            .map(\.id)

        let existing = Set(publications.map(\.id))
        let documents = ((try? await store?.search(trimmed)) ?? [])
            .filter { existing.contains($0.publicationID) }

        guard !Task.isCancelled else { return GlobalSearchResults() }
        return GlobalSearchResults(
            titleMatches: titleMatches,
            documents: documents,
            annotations: annotations(matching: trimmed, in: existing)
        )
    }

    /// Notas (cuerpo o etiquetas) y destacados (texto seleccionado), los más recientes primero.
    private func annotations(matching query: String, in publications: Set<UUID>) -> [AnnotationHit] {
        let context = container.mainContext
        let notes = ((try? context.fetch(FetchDescriptor<NoteModel>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))) ?? [])
            .filter { note in
                publications.contains(note.publicationID)
                    && (note.body.localizedStandardContains(query) || note.tags.contains { $0.localizedStandardContains(query) })
            }
            .prefix(Self.maxAnnotationsPerKind)
            .map { AnnotationHit(id: $0.id, publicationID: $0.publicationID, kind: .note, text: $0.body, anchor: $0.anchor) }

        let highlights = ((try? context.fetch(FetchDescriptor<HighlightModel>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))) ?? [])
            .filter { publications.contains($0.publicationID) && $0.selectedText.localizedStandardContains(query) }
            .prefix(Self.maxAnnotationsPerKind)
            .map { AnnotationHit(id: $0.id, publicationID: $0.publicationID, kind: .highlight, text: $0.selectedText, anchor: $0.anchor) }

        return Array(notes) + Array(highlights)
    }
}
