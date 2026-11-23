import Foundation

// MARK: - Repositorios con analítica

// Envoltorios que registran en el panel administrativo cuándo se CREA un resaltado,
// una nota o un marcador, sin tocar cada lector. `save` es un upsert: solo cuenta si el
// id no existía antes (editar el color o el texto de una nota no se cuenta de nuevo).
// Nunca se envía el texto, la nota ni el documento: solo el nombre del evento.

final class AnalyticsHighlightRepository: HighlightRepository, @unchecked Sendable {
    private let base: any HighlightRepository
    private let analytics: any AnalyticsService

    init(base: any HighlightRepository, analytics: any AnalyticsService) {
        self.base = base
        self.analytics = analytics
    }

    func fetch(forPublication publicationID: UUID) async throws -> [Highlight] { try await base.fetch(forPublication: publicationID) }
    func fetchAll() async throws -> [Highlight] { try await base.fetchAll() }
    func fetch(id: UUID) async throws -> Highlight? { try await base.fetch(id: id) }
    func delete(id: UUID) async throws { try await base.delete(id: id) }

    func save(_ highlight: Highlight) async throws {
        let isNew = ((try? await base.fetch(id: highlight.id)) ?? nil) == nil
        try await base.save(highlight)
        if isNew { analytics.track(.highlightCreated) }
    }
}

final class AnalyticsNoteRepository: NoteRepository, @unchecked Sendable {
    private let base: any NoteRepository
    private let analytics: any AnalyticsService

    init(base: any NoteRepository, analytics: any AnalyticsService) {
        self.base = base
        self.analytics = analytics
    }

    func fetch(forPublication publicationID: UUID) async throws -> [Note] { try await base.fetch(forPublication: publicationID) }
    func fetch(id: UUID) async throws -> Note? { try await base.fetch(id: id) }
    func fetchAll() async throws -> [Note] { try await base.fetchAll() }
    func delete(id: UUID) async throws { try await base.delete(id: id) }

    func save(_ note: Note) async throws {
        let isNew = ((try? await base.fetch(id: note.id)) ?? nil) == nil
        try await base.save(note)
        if isNew { analytics.track(.noteCreated) }
    }
}

final class AnalyticsBookmarkRepository: BookmarkRepository, @unchecked Sendable {
    private let base: any BookmarkRepository
    private let analytics: any AnalyticsService

    init(base: any BookmarkRepository, analytics: any AnalyticsService) {
        self.base = base
        self.analytics = analytics
    }

    func fetch(forPublication publicationID: UUID) async throws -> [Bookmark] { try await base.fetch(forPublication: publicationID) }
    func fetch(id: UUID) async throws -> Bookmark? { try await base.fetch(id: id) }
    func delete(id: UUID) async throws { try await base.delete(id: id) }

    func save(_ bookmark: Bookmark) async throws {
        let isNew = ((try? await base.fetch(id: bookmark.id)) ?? nil) == nil
        try await base.save(bookmark)
        if isNew { analytics.track(.bookmarkAdded) }
    }
}

// MARK: - Acciones de estudio

extension AnalyticsService {
    /// Registra una acción del lector (diccionario, traducción o IA) con el mismo nombre
    /// de acción que usan los lectores ("define", "translate_es", "explain", …).
    /// Solo se envía el tipo de acción, nunca el texto seleccionado ni la respuesta.
    func trackStudyAction(_ action: String) {
        if action == "define" {
            track(.dictionaryLookedUp, properties: ["source": "ai"])
        } else if action.hasPrefix("translate") {
            var properties: [String: Any] = ["mode": "on_device"]
            if action.hasPrefix("translate_") {
                properties["target_language"] = String(action.dropFirst("translate_".count))
            }
            track(.translationRequested, properties: properties)
        } else {
            track(.aiQueryExecuted, properties: ["action": action])
        }
    }
}
