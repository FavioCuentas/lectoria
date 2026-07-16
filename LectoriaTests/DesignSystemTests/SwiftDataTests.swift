import Testing
import Foundation
import SwiftData
@testable import Lectoria

// MARK: - SwiftDataTests

@MainActor
struct SwiftDataTests {
    private let container: ModelContainer

    init() {
        // Inicializar ModelContainer en memoria para pruebas
        self.container = ModelContainerFactory.create(isStoredInMemoryOnly: true)
    }

    @Test("SwiftData container is initialized and empty")
    func containerInitialization() throws {
        let context = container.mainContext
        let fetchDescriptor = FetchDescriptor<PublicationModel>()
        let count = try context.fetchCount(fetchDescriptor)
        #expect(count == 0)
    }

    @Test("PublicationModel CRUD operations")
    func publicationCRUD() throws {
        let context = container.mainContext
        
        let id = UUID()
        let model = PublicationModel(
            id: id,
            title: "Crónica de una muerte anunciada",
            author: "Gabriel García Márquez",
            publicationTypeRaw: "epub",
            localFileName: "cronica.epub",
            mimeType: "application/epub+zip",
            fileSize: 1_200_000,
            sha256: "cronica_sha256"
        )
        
        // Insert
        context.insert(model)
        try context.save()
        
        // Read
        var descriptor = FetchDescriptor<PublicationModel>()
        var results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.title == "Crónica de una muerte anunciada")
        
        // Update
        results.first?.isFavorite = true
        try context.save()
        
        descriptor = FetchDescriptor<PublicationModel>(predicate: #Predicate { $0.id == id })
        results = try context.fetch(descriptor)
        #expect(results.first?.isFavorite == true)
        
        // Delete
        if let first = results.first {
            context.delete(first)
        }
        try context.save()
        
        results = try context.fetch(descriptor)
        #expect(results.isEmpty)
    }

    @Test("Cascade deletion of related entities")
    func cascadeDeletion() throws {
        let context = container.mainContext
        
        let pubID = UUID()
        let publication = PublicationModel(
            id: pubID,
            title: "Relato de un náufrago",
            publicationTypeRaw: "epub",
            localFileName: "naufrago.epub",
            mimeType: "application/epub+zip",
            fileSize: 900_000,
            sha256: "naufrago_sha256"
        )
        context.insert(publication)
        
        // Add Bookmark
        let bookmark = BookmarkModel(id: UUID(), publicationID: pubID, anchor: "epubcfi(/6/2[chap-1]!/4/2/1:10)")
        bookmark.publication = publication
        context.insert(bookmark)
        
        // Add Highlight
        let highlight = HighlightModel(id: UUID(), publicationID: pubID, anchor: "epubcfi(/6/2[chap-1]!/4/2/1:20)", selectedText: "El mar estaba en calma")
        highlight.publication = publication
        context.insert(highlight)
        
        // Add Note (associated with Highlight)
        let note = NoteModel(id: UUID(), publicationID: pubID, highlightID: highlight.id, anchor: highlight.anchor, body: "Buena descripción del mar.")
        note.publication = publication
        note.highlight = highlight
        context.insert(note)
        
        try context.save()
        
        // Verify insertions
        #expect(try context.fetchCount(FetchDescriptor<BookmarkModel>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<HighlightModel>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<NoteModel>()) == 1)
        
        // Delete Publication
        context.delete(publication)
        try context.save()
        
        // Verify cascade deletion wiped bookmarks, highlights, and notes
        #expect(try context.fetchCount(FetchDescriptor<BookmarkModel>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<HighlightModel>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<NoteModel>()) == 0)
    }

    @Test("Repository fetch and save wrappers")
    func repositoryOperations() async throws {
        let pubRepo = SwiftDataPublicationRepository(container: container)
        
        let record = PublicationRecord.newImport(
            title: "El coronel no tiene quien le escriba",
            author: "Gabriel García Márquez",
            publicationType: .pdf,
            localFileName: "el-coronel.pdf",
            mimeType: "application/pdf",
            fileSize: 1_800_000,
            sha256: "el_coronel_sha256"
        )
        
        // Save using repository
        try await pubRepo.save(record)
        
        // Fetch using repository
        let fetched = try await pubRepo.fetch(id: record.id)
        #expect(fetched != nil)
        #expect(fetched?.title == "El coronel no tiene quien le escriba")
        
        let all = try await pubRepo.fetchAll()
        #expect(all.count == 1)
    }
}
