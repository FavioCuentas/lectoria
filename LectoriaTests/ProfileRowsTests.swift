import Testing
import Foundation
@testable import Lectoria

// MARK: - Etiqueta del plan

struct SubscriptionPlanLabelTests {
    @Test func testLabels() {
        #expect(SubscriptionPlanLabel.text(isPremium: false, productID: nil) == "Gratuito")
        #expect(SubscriptionPlanLabel.text(isPremium: true, productID: "com.lectoria.premium.founder") == "Premium Fundador")
        #expect(SubscriptionPlanLabel.text(isPremium: true, productID: "com.lectoria.premium.yearly") == "Premium anual")
        #expect(SubscriptionPlanLabel.text(isPremium: true, productID: "com.lectoria.premium.semiannual") == "Premium semestral")
        #expect(SubscriptionPlanLabel.text(isPremium: true, productID: "com.lectoria.premium.lifetime") == "Premium de por vida")
        #expect(SubscriptionPlanLabel.text(isPremium: true, productID: nil) == "Premium")
        #expect(SubscriptionPlanLabel.text(isPremium: true, productID: "otro") == "Premium")
    }

    @Test func testNeverShowsSimulatedLabel() {
        for id in [nil, "com.lectoria.premium.founder", "x"] as [String?] {
            #expect(!SubscriptionPlanLabel.text(isPremium: true, productID: id).contains("Simulado"))
        }
    }
}

// MARK: - Exportar notas y destacados

struct AnnotationsExporterTests {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)

    private func publication(_ title: String, author: String? = nil) -> PublicationRecord {
        PublicationRecord(id: UUID(), title: title, author: author, publicationType: .pdf,
                          localFileName: "\(title).pdf", mimeType: "application/pdf", fileSize: 1, sha256: title)
    }

    @Test func testEmptyExportExplainsThereIsNothing() {
        let markdown = AnnotationsExporter.markdown(publications: [], highlights: [], notes: [], exportedAt: date)
        #expect(markdown.hasPrefix("# Mis notas de Lectoria"))
        #expect(markdown.contains("Todavía no tienes notas ni destacados."))
    }

    @Test func testGroupsByDocumentAlphabeticallyWithNotesUnderTheirHighlight() {
        let moby = publication("Moby Dick", author: "Herman Melville")
        let ana = publication("Ana Karenina")
        let unused = publication("Sin anotaciones")
        let first = Highlight(publicationID: moby.id, anchor: "a", selectedText: "Llamadme Ismael.", createdAt: date)
        let second = Highlight(publicationID: moby.id, anchor: "b", selectedText: "La ballena blanca.", createdAt: date.addingTimeInterval(60))
        let attached = Note(publicationID: moby.id, highlightID: second.id, body: "Símbolo central")
        let loose = Note(publicationID: ana.id, body: "Releer el capítulo 3")

        let markdown = AnnotationsExporter.markdown(
            publications: [moby, ana, unused],
            highlights: [second, first],
            notes: [attached, loose],
            exportedAt: date
        )

        #expect(!markdown.contains("Sin anotaciones"))
        let anaRange = markdown.range(of: "## Ana Karenina")!
        let mobyRange = markdown.range(of: "## Moby Dick — Herman Melville")!
        #expect(anaRange.lowerBound < mobyRange.lowerBound)
        #expect(markdown.contains("- Releer el capítulo 3"))

        let ismael = markdown.range(of: "> Llamadme Ismael.")!
        let ballena = markdown.range(of: "> La ballena blanca.")!
        let nota = markdown.range(of: "Nota: Símbolo central")!
        #expect(ismael.lowerBound < ballena.lowerBound)
        #expect(ballena.upperBound < nota.lowerBound)
        // La nota ligada al destacado no se repite como nota suelta.
        #expect(!markdown.contains("- Símbolo central"))
    }

    @Test func testAnnotationsOfMissingDocumentsAreKept() {
        let orphan = Highlight(publicationID: UUID(), anchor: "a", selectedText: "Texto huérfano")
        let markdown = AnnotationsExporter.markdown(publications: [], highlights: [orphan], notes: [], exportedAt: date)
        #expect(markdown.contains("## Documento eliminado"))
        #expect(markdown.contains("> Texto huérfano"))
    }

    @Test func testMultilineTextStaysInsideQuote() {
        let book = publication("Libro")
        let highlight = Highlight(publicationID: book.id, anchor: "a", selectedText: "línea uno\nlínea dos")
        let markdown = AnnotationsExporter.markdown(publications: [book], highlights: [highlight], notes: [], exportedAt: date)
        #expect(markdown.contains("> línea uno\n> línea dos"))
    }

    @Test func testFileNameUsesExportDate() {
        let name = AnnotationsExporter.fileName(exportedAt: date)
        #expect(name.hasPrefix("Lectoria-notas-"))
        #expect(name.hasSuffix(".md"))
    }
}
