import Testing
import Foundation
import SwiftData
@testable import Lectoria

// MARK: - AnnotationTests

@MainActor
struct AnnotationTests {
    private let container: ModelContainer

    init() {
        // Inicializar contenedor in-memory para base de datos de test
        let schema = Schema([
            PublicationModel.self,
            BookmarkModel.self,
            HighlightModel.self,
            NoteModel.self,
            ReadingProgressModel.self,
            ReadingSessionModel.self,
            AIUsageModel.self,
            SubscriptionEntitlementModel.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        self.container = try! ModelContainer(for: schema, configurations: config)
    }

    @Test("Highlight CRUD operations including fetchAll")
    func highlightCrudOperations() async throws {
        let repository = SwiftDataHighlightRepository(container: container)
        let pubID = UUID()
        
        let highlight1 = Highlight(
            publicationID: pubID,
            anchor: "anchor_1",
            selectedText: "Texto destacado uno",
            category: "Idea principal",
            colorToken: "blue"
        )
        let highlight2 = Highlight(
            publicationID: pubID,
            anchor: "anchor_2",
            selectedText: "Texto destacado dos",
            category: "Duda",
            colorToken: "purple"
        )

        // 1. Guardar
        try await repository.save(highlight1)
        try await repository.save(highlight2)

        // 2. Fetch por publicación
        let list = try await repository.fetch(forPublication: pubID)
        #expect(list.count == 2)
        #expect(list.contains(where: { $0.selectedText == "Texto destacado uno" }))
        
        // 3. Fetch por ID
        let fetched = try await repository.fetch(id: highlight1.id)
        #expect(fetched != nil)
        #expect(fetched?.selectedText == "Texto destacado uno")
        
        // 4. FetchAll global
        let all = try await repository.fetchAll()
        #expect(all.count == 2)

        // 5. Eliminar
        try await repository.delete(id: highlight1.id)
        let afterDelete = try await repository.fetch(forPublication: pubID)
        #expect(afterDelete.count == 1)
        #expect(afterDelete.first?.selectedText == "Texto destacado dos")
    }

    @Test("Note CRUD operations including fetchAll")
    func noteCrudOperations() async throws {
        let repository = SwiftDataNoteRepository(container: container)
        let pubID = UUID()
        
        let note1 = Note(
            publicationID: pubID,
            body: "Nota independiente de prueba",
            tags: ["examen", "importante"]
        )
        let note2 = Note(
            publicationID: pubID,
            body: "Otra nota de prueba",
            tags: ["resumen"]
        )

        // 1. Guardar
        try await repository.save(note1)
        try await repository.save(note2)

        // 2. Fetch por publicación
        let list = try await repository.fetch(forPublication: pubID)
        #expect(list.count == 2)
        #expect(list.contains(where: { $0.body == "Nota independiente de prueba" }))
        
        // 3. FetchAll global
        let all = try await repository.fetchAll()
        #expect(all.count == 2)

        // 4. Eliminar
        try await repository.delete(id: note1.id)
        let afterDelete = try await repository.fetch(forPublication: pubID)
        #expect(afterDelete.count == 1)
        #expect(afterDelete.first?.body == "Otra nota de prueba")
    }
}
