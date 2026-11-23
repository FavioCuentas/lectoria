import Testing
import Foundation
import SwiftData
@testable import Lectoria

// MARK: - AnalyticsTrackingTests

/// Eventos de herramientas de estudio que alimentan el panel administrativo web.
@MainActor
struct AnalyticsTrackingTests {
    private let container = ModelContainerFactory.create(isStoredInMemoryOnly: true)

    private func names(_ mock: MockAnalyticsService) -> [String] {
        mock.trackedEvents.map(\.name.rawValue)
    }

    @Test("Crear un resaltado se reporta una vez; editarlo no")
    func highlightCreatedOnlyOnce() async throws {
        let mock = MockAnalyticsService()
        let repo = AnalyticsHighlightRepository(base: SwiftDataHighlightRepository(container: container), analytics: mock)
        var highlight = Highlight(publicationID: UUID(), anchor: "a", selectedText: "texto privado")

        try await repo.save(highlight)
        highlight.colorToken = "blue"
        try await repo.save(highlight)

        #expect(names(mock) == ["highlight_created"])
        #expect(mock.trackedEvents.allSatisfy { $0.properties.isEmpty })
    }

    @Test("Notas y marcadores nuevos se reportan sin contenido")
    func noteAndBookmarkCreated() async throws {
        let mock = MockAnalyticsService()
        let notes = AnalyticsNoteRepository(base: SwiftDataNoteRepository(container: container), analytics: mock)
        let bookmarks = AnalyticsBookmarkRepository(base: SwiftDataBookmarkRepository(container: container), analytics: mock)
        let note = Note(publicationID: UUID(), body: "mi nota secreta")

        try await notes.save(note)
        try await notes.save(note)
        try await bookmarks.save(Bookmark(publicationID: UUID(), anchor: "p1"))

        #expect(names(mock) == ["note_created", "bookmark_added"])
        #expect(!mock.trackedEvents.contains { "\($0.properties)".contains("secreta") })
    }

    @Test("Acciones del lector: diccionario, traducción e IA")
    func studyActionsMapToPanelEvents() {
        let mock = MockAnalyticsService()
        mock.trackStudyAction("define")
        mock.trackStudyAction("translate_es")
        mock.trackStudyAction("summarize")

        #expect(names(mock) == ["dictionary_looked_up", "translation_requested", "ai_query_executed"])
        #expect(mock.trackedEvents[1].properties["target_language"] as? String == "es")
        #expect(mock.trackedEvents[2].properties["action"] as? String == "summarize")
    }

    @Test("AppDependencies expone los repositorios con analítica")
    func dependenciesUseTrackingRepositories() {
        let deps = AppDependencies(modelContainer: container, analyticsService: MockAnalyticsService())
        #expect(deps.highlightRepository is AnalyticsHighlightRepository)
        #expect(deps.noteRepository is AnalyticsNoteRepository)
        #expect(deps.bookmarkRepository is AnalyticsBookmarkRepository)
    }
}
